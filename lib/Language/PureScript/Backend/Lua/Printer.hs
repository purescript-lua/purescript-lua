module Language.PureScript.Backend.Lua.Printer where

import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Types
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Prettyprinter
  ( Doc
  , Pretty (pretty)
  , brackets
  , comma
  , dquotes
  , flatAlt
  , group
  , hardline
  , hsep
  , indent
  , lbrace
  , parens
  , punctuate
  , rbrace
  , sep
  , tupled
  , vsep
  , (<+>)
  )
import Prelude hiding (group)

-- | Document with no annotations
type ADoc = Doc ()

type PADoc = (Precedence, ADoc)

printLuaChunk ∷ Lua.Chunk → ADoc
printLuaChunk = vsep . printStatements . fmap Lua.ann

{- | Print a statement sequence, terminating a statement with @;@ whenever
the next one starts with an open paren: @local a = f\n(g).x = 1@ would
otherwise read as the call @f(g)@ (Lua 5.1 rejects it as "ambiguous
syntax"), and the semicolon after the previous statement is the only
separator its grammar allows.
-}
printStatements ∷ [Annotated Comments StatementF] → [ADoc]
printStatements statements =
  zipWith
    (\stat next → printStatementA stat <> separator next)
    statements
    (fmap Just (drop 1 statements) <> [Nothing])
 where
  separator = \case
    Just (Ann next) | startsWithOpenParen next → ";"
    _ → mempty

{- | Whether the statement's printed form begins with @(@.
Mirrors 'wrapIndexedPrefix' and 'wrapCallTarget'.
-}
startsWithOpenParen ∷ StatementF a → Bool
startsWithOpenParen = \case
  Assign (Ann variable :| _) _values → varStarts variable
  CallStatement (Ann e) → prefixStarts e
  _ → False
 where
  varStarts ∷ VarF a → Bool
  varStarts = \case
    VarName _ → False
    VarIndex (Ann e) _ → indexedPrefixStarts e
    VarField (Ann e) _ → indexedPrefixStarts e
  -- 'wrapIndexedPrefix' prints every non-'Var' base parenthesised.
  indexedPrefixStarts ∷ ExpF a → Bool
  indexedPrefixStarts = \case
    Var (Ann v) → varStarts v
    _ → True
  -- 'wrapCallTarget' also lets (method) calls through bare.
  prefixStarts ∷ ExpF a → Bool
  prefixStarts = \case
    Var (Ann v) → varStarts v
    FunctionCall (Ann f) _args → prefixStarts f
    MethodCall (Ann o) _name _args → prefixStarts o
    _ → True

{- | Comments attached to a node print on their own lines before it. The
'hardline' is deliberate: a line comment must be terminated by a newline, so
any enclosing 'group' falls back to the vertical layout.
-}
withComments ∷ Comments → ADoc → ADoc
withComments comments doc =
  foldr
    (\c d → pretty c <> hardline <> d)
    doc
    (concatMap Text.lines comments)

printStatementA ∷ Annotated Comments StatementF → ADoc
printStatementA (comments, statement) =
  withComments comments (printStatement statement)

printStatement ∷ Lua.Statement → ADoc
printStatement = \case
  Lua.Assign variables values →
    commaSep (printVar . unAnn <$> toList variables)
      <+> "="
      <+> commaSep (printedExpA <$> toList values)
  Lua.Local names values →
    printLocal (toList names) (printedExpA <$> values)
  Lua.IfThenElse predicate thenBlock elseBlock →
    printIfThenElse predicate thenBlock elseBlock
  Lua.Return values →
    case values of
      [] → "return"
      _ → "return" <+> commaSep (printedExpA <$> values)
  Lua.CallStatement e →
    printedExpA e
  Lua.Do body →
    sep ["do", flex (printStatements body), "end"]
  Lua.While predicate body →
    sep
      [ hsep ["while", printedExpA predicate, "do"]
      , flex (printStatements body)
      , "end"
      ]
  Lua.Repeat body predicate →
    sep
      [ "repeat"
      , flex (printStatements body)
      , "until" <+> printedExpA predicate
      ]
  Lua.ForNum name start limit step body →
    sep
      [ hsep
          [ "for"
          , printName name
          , "="
          , commaSep
              ( printedExpA
                  <$> ([start, limit] <> maybeToList step)
              )
          , "do"
          ]
      , flex (printStatements body)
      , "end"
      ]
  Lua.ForIn names exprs body →
    sep
      [ hsep
          [ "for"
          , commaSep (printName <$> toList names)
          , "in"
          , commaSep (printedExpA <$> toList exprs)
          , "do"
          ]
      , flex (printStatements body)
      , "end"
      ]
  Lua.LocalFunction name params body →
    sep
      [ group ("local function" <+> printName name <> printParams params)
      , flex (printStatements body)
      , "end"
      ]
  Lua.Break → "break"

-- | Printed expression without a precedence
printedExp ∷ Lua.Exp → ADoc
printedExp = snd . printExp

printedExpA ∷ Annotated Comments ExpF → ADoc
printedExpA = snd . printExpA

printExpA ∷ Annotated Comments ExpF → PADoc
printExpA (comments, e) =
  let (precedence, doc) = printExp e
   in (precedence, withComments comments doc)

printExp ∷ Lua.Exp → PADoc
printExp = \case
  Lua.Nil → (PrecAtom, "nil")
  Lua.Boolean b → (PrecAtom, if b then "true" else "false")
  -- A negative literal renders with a leading minus, which Lua reads as the
  -- unary operator, so it must carry the unary precedence: as an atom, "-2"
  -- as the base of `^` would print unparenthesised and reassociate to
  -- -(2 ^ e).
  Lua.Float f
    | isNaN f → (PrecAtom, "(0/0)")
    | isInfinite f && f > 0 → (PrecAtom, "math.huge")
    | isInfinite f → (prec Lua.Negate, "-math.huge")
    | f < 0 → (prec Lua.Negate, pretty f)
    | otherwise → (PrecAtom, pretty f)
  Lua.Integer i
    | i < 0 → (prec Lua.Negate, pretty i)
    | otherwise → (PrecAtom, pretty i)
  Lua.String t → (PrecAtom, dquotes (pretty t))
  Lua.Vararg → (PrecAtom, "...")
  Lua.Function params body → (PrecFunction, printFunction params body)
  Lua.TableCtor rows → (PrecTable, printTableCtor rows)
  Lua.UnOp op a → printUnaryOp op (printExpA a)
  Lua.BinOp op l r → printBinaryOp op (printExpA l) (printExpA r)
  Lua.Var (Ann v) → (PrecAtom, printVar v)
  Lua.FunctionCall (Ann prefix) args →
    (PrecPrefix, printFunctionCall prefix (printExpA <$> args))
  Lua.MethodCall (Ann obj) name args →
    (PrecPrefix, printMethodCall obj name (printExpA <$> args))
  Lua.Paren e → (PrecAtom, parens (printedExpA e))

printUnaryOp ∷ Lua.UnaryOp → PADoc → PADoc
printUnaryOp op (_, a) = (prec op, pretty (sym op) <> parens a)

-- See Note [Lua operator precedence] in ...Backend.Lua.Types
printBinaryOp ∷ Lua.BinaryOp → PADoc → PADoc → PADoc
printBinaryOp op l r =
  (prec op, wrapLeft l <+> pretty (sym op) <+> wrapRight r)
 where
  (wrapLeft, wrapRight) = case Lua.assoc op of
    Lua.LeftAssoc → (wrapPrec op, wrapPrecGte op)
    Lua.RightAssoc → (wrapPrecGte op, wrapPrec op)

printFunction
  ∷ [Annotated Comments ParamF] → [Annotated Comments StatementF] → ADoc
printFunction params body =
  sep [group ("function" <> printParams params), flex fbody, "end"]
 where
  fbody = printStatements body

printParams ∷ [Annotated Comments ParamF] → ADoc
printParams params =
  tupled do
    Ann param ← params
    case param of
      ParamNamed n → [printName n]
      ParamUnused → []
      ParamVararg → ["..."]

printTableCtor ∷ [Annotated Comments TableRowF] → ADoc
printTableCtor [] = "{}"
printTableCtor tableRows = sep [lbrace, flex rows, rbrace]
 where
  rows = punctuate comma $ fmap printRowA tableRows

printRowA ∷ Annotated Comments TableRowF → ADoc
printRowA (comments, row) = withComments comments (printRow row)

printRow ∷ Lua.TableRow → ADoc
printRow = \case
  Lua.TableRowKV k vexp →
    brackets (printedExpA k) <+> "=" <+> printedExpA vexp
  Lua.TableRowNV name vexp →
    printName name <+> "=" <+> printedExpA vexp
  Lua.TableRowV vexp →
    printedExpA vexp

printVar ∷ Lua.Var → ADoc
printVar = \case
  Lua.VarName name → printName name
  Lua.VarIndex (Ann e) i → wrapIndexedPrefix e <> brackets (printedExpA i)
  Lua.VarField (Ann e) n → wrapIndexedPrefix e <> "." <> printName n

printFunctionCall ∷ Lua.Exp → [PADoc] → ADoc
printFunctionCall prefixExp args =
  wrapCallTarget prefixExp
    <> parens (hsep (punctuate comma (snd <$> args)))

printMethodCall ∷ Lua.Exp → Lua.Name → [PADoc] → ADoc
printMethodCall prefixExp name args =
  wrapCallTarget prefixExp
    <> ":"
    <> printName name
    <> parens (hsep (punctuate comma (snd <$> args)))

{- | Lua's grammar allows a bare variable before '.' or '[...]'; every other
expression form -- literals, table constructors, function calls, operator
results -- must be parenthesised there. A function call is technically
also valid bare, but wrapping it too is harmless and matches existing
output.
-}
wrapIndexedPrefix ∷ Lua.Exp → ADoc
wrapIndexedPrefix e@(Lua.Var _) = printedExp e
wrapIndexedPrefix e = parens (printedExp e)

{- | Lua's grammar allows a bare variable or function call (to permit
chaining, e.g. @f()()@) before a call's argument list; every other
expression form -- literals, table constructors, function definitions,
operator results -- must be parenthesised there.
-}
wrapCallTarget ∷ Lua.Exp → ADoc
wrapCallTarget e@(Lua.Var _) = printedExp e
wrapCallTarget e@(Lua.FunctionCall _ _) = printedExp e
wrapCallTarget e@(Lua.MethodCall {}) = printedExp e
wrapCallTarget e = parens (printedExp e)

printLocal ∷ [Lua.Name] → [ADoc] → ADoc
printLocal names values =
  "local" <+> case values of
    [] → commaSep (printName <$> names)
    _ → commaSep (printName <$> names) <+> "=" <+> commaSep values

printRequire ∷ Lua.ChunkName → ADoc
printRequire name =
  vsep ["require" <> parens (dquotes (printChunkName name)), ""]

printIfThenElse
  ∷ Annotated Comments ExpF
  → [Annotated Comments StatementF]
  → [Annotated Comments StatementF]
  → ADoc
printIfThenElse predicate thenBlock elseBlock =
  sep . join $
    [[hsep ["if", printedExpA predicate, "then"], thenDoc]]
      <> elseChain elseBlock
      <> [["end"]]
 where
  thenDoc = flex (printStatements thenBlock)
  -- An else-block holding exactly one (comment-free) 'IfThenElse' prints as
  -- an @elseif@ continuation of the same statement, mirroring how the parser
  -- reads @elseif@ chains into nested else-blocks.
  elseChain = \case
    [] → []
    [([], Lua.IfThenElse p tb eb)] →
      [hsep ["elseif", printedExpA p, "then"], flex (printStatements tb)]
        : elseChain eb
    stats → [["else", flex (printStatements stats)]]

printName ∷ Lua.Name → ADoc
printName = pretty

printChunkName ∷ Lua.ChunkName → ADoc
printChunkName = pretty

--------------------------------------------------------------------------------
-- Utility functions -----------------------------------------------------------

commaSep ∷ [ADoc] → ADoc
commaSep = hsep . punctuate comma

flex ∷ Foldable t ⇒ t ADoc → ADoc
flex b =
  flatAlt
    (indent 2 $ vsep $ toList b) -- if doesn't fit one line
    (hsep $ toList b) -- when fits into one line

wrapPrec ∷ HasPrecedence p ⇒ p → PADoc → ADoc
wrapPrec = wrapPrecWith (>)

wrapPrecGte ∷ HasPrecedence p ⇒ p → PADoc → ADoc
wrapPrecGte = wrapPrecWith (>=)

wrapPrecWith
  ∷ HasPrecedence p
  ⇒ (Precedence → Precedence → Bool)
  → p
  → PADoc
  → ADoc
wrapPrecWith f p1 (p2, doc)
  | prec p1 `f` p2 = parens doc
  | otherwise = doc
