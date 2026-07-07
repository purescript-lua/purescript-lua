{- | Hedgehog generators for the Lua AST, used by the print\/parse round-trip
property in 'Language.PureScript.Backend.Lua.Parser.Spec', the traversal
identity property, and the external-arbiter properties in
'Language.PureScript.Backend.Lua.Differential.Spec'.

The generators cover the /canonical/ AST shapes — the ones code generation
and the parser itself produce — so that @parse . print@ is the identity:

  * Numeric literals are non-negative and finite: a negative or non-finite
    value prints with a leading operator or as a synthetic expression
    (@-2@, @math.huge@, @(0\/0)@), which parses back as that expression, not
    as a literal.
  * String payloads avoid characters that engage escape normalization.
  * Only Lua 5.1 operators are drawn ('ParamUnused' is likewise skipped:
    it prints as nothing).
  * 'Paren' wraps only multi-valued expressions (calls, @...@); around
    anything else the parser drops grouping parens.
  * @return@ appears only where the Lua grammar allows it: closing a block.
    'Break' is left to example-based tests, since Lua 5.1 additionally
    requires an enclosing loop.
  * @...@ appears only where the reference parser allows it: under a
    function whose parameter list ends in @...@, or at the top level (the
    main chunk is a vararg function). 'VarargScope' threads that through.
  * Comments (roughly one slot in three) attach to statement and table-row
    annotation slots only — the placements the parser pins exactly.
    Expression slots stay comment-free: placement there is not stable under
    print\/parse and is documented as a non-goal.
-}
module Language.PureScript.Backend.Lua.Gen where

import Data.Set qualified as Set
import Data.Text qualified as Text
import Hedgehog (MonadGen)
import Hedgehog.Gen.Extended qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Prelude hiding (exp)

-- | Whether @...@ is legal in the position being generated.
type VarargScope = Bool

--------------------------------------------------------------------------------
-- Top-level entry points (main chunk: vararg scope) ---------------------------

block ∷ ∀ m. MonadGen m ⇒ m [Lua.Annotated Lua.Comments Lua.StatementF]
block = blockIn True

statement ∷ ∀ m. MonadGen m ⇒ m Lua.Statement
statement = statementIn True

exp ∷ ∀ m. MonadGen m ⇒ m Lua.Exp
exp = expIn True

--------------------------------------------------------------------------------
-- Comments in annotation slots ------------------------------------------------

{- | A line comment. The @"-- "@ prefix (with the space) structurally rules
out a long-bracket opener; the payload has no line breaks and no trailing
whitespace (a layout is not obliged to preserve it).
-}
comment ∷ ∀ m. MonadGen m ⇒ m Text
comment = do
  payload ←
    Gen.text (Range.linear 1 12) $
      Gen.element (['a' .. 'z'] <> ['0' .. '9'] <> " _")
  let trimmed = Text.dropWhileEnd (== ' ') payload
  pure ("-- " <> if Text.null trimmed then "c" else trimmed)

comments ∷ ∀ m. MonadGen m ⇒ m Lua.Comments
comments =
  Gen.frequency
    [ (2, pure [])
    , (1, Gen.list (Range.linear 1 2) comment)
    ]

-- | Annotate a node with generated 'comments'.
annotated
  ∷ ∀ m f. MonadGen m ⇒ m (f Lua.Comments) → m (Lua.Annotated Lua.Comments f)
annotated gen = (,) <$> comments <*> gen

--------------------------------------------------------------------------------
-- Statements ------------------------------------------------------------------

blockIn
  ∷ ∀ m
   . MonadGen m
  ⇒ VarargScope
  → m [Lua.Annotated Lua.Comments Lua.StatementF]
blockIn vararg = do
  statements ← Gen.list (Range.linear 0 3) (annotated (statementIn vararg))
  final ← Gen.maybe (annotated (returnStatementIn vararg))
  pure (statements <> maybeToList final)

returnStatementIn ∷ ∀ m. MonadGen m ⇒ VarargScope → m Lua.Statement
returnStatementIn vararg =
  Lua.Return <$> Gen.list (Range.linear 0 2) (Lua.ann <$> expIn vararg)

statementIn ∷ ∀ m. MonadGen m ⇒ VarargScope → m Lua.Statement
statementIn vararg =
  Gen.recursiveFrequency
    [ (2, assign)
    , (3, localStat)
    , (2, callStatement)
    ]
    [ (2, ifThenElse)
    , (1, Lua.Do <$> blockIn vararg)
    , (1, Lua.While . Lua.ann <$> expIn vararg <*> blockIn vararg)
    , (1, Lua.Repeat <$> blockIn vararg <*> (Lua.ann <$> expIn vararg))
    , (1, forNum)
    , (1, forIn)
    , (1, localFunction)
    ]
 where
  assign = do
    vars ← Gen.nonEmpty (Range.linear 1 2) (Lua.ann <$> varIn vararg)
    vals ← Gen.nonEmpty (Range.linear 1 2) (Lua.ann <$> expIn vararg)
    pure (Lua.Assign vars vals)
  localStat = do
    names ← Gen.nonEmpty (Range.linear 1 2) name
    vals ← Gen.list (Range.linear 0 2) (Lua.ann <$> expIn vararg)
    pure (Lua.Local names vals)
  callStatement = Lua.CallStatement . Lua.ann <$> callExpIn vararg
  ifThenElse =
    Lua.IfThenElse . Lua.ann
      <$> expIn vararg
      <*> blockIn vararg
      <*> blockIn vararg
  forNum = do
    n ← name
    start ← Lua.ann <$> expIn vararg
    limit ← Lua.ann <$> expIn vararg
    step ← Gen.maybe (Lua.ann <$> expIn vararg)
    Lua.ForNum n start limit step <$> blockIn vararg
  forIn = do
    names ← Gen.nonEmpty (Range.linear 1 3) name
    exps ← Gen.nonEmpty (Range.linear 1 2) (Lua.ann <$> expIn vararg)
    Lua.ForIn names exps <$> blockIn vararg
  localFunction = do
    n ← name
    (params, body) ← functionParts
    pure (Lua.LocalFunction n params body)

--------------------------------------------------------------------------------
-- Expressions -----------------------------------------------------------------

expIn ∷ ∀ m. MonadGen m ⇒ VarargScope → m Lua.Exp
expIn vararg =
  Gen.recursiveFrequency
    ( [ (1, pure Lua.Nil)
      , (2, Lua.Boolean <$> Gen.bool)
      , (2, Lua.Integer <$> Gen.integral (Range.linear 0 0xFFFFFFFF))
      , (2, Lua.Float <$> Gen.double (Range.linearFrac 0 1.0e9))
      , (2, Lua.String <$> stringPayload)
      , (2, Lua.varName <$> name)
      ]
        <> [(1, pure Lua.Vararg) | vararg]
    )
    [ (3, Lua.var <$> varIn vararg)
    , (3, uncurry Lua.Function <$> functionParts)
    , (2, Lua.TableCtor <$> Gen.list (Range.linear 0 3) (tableRowIn vararg))
    , (2, Lua.UnOp <$> unaryOp <*> (Lua.ann . adjusted <$> expIn vararg))
    ,
      ( 3
      , Lua.BinOp
          <$> binaryOp
          <*> (Lua.ann <$> expIn vararg)
          <*> (Lua.ann <$> expIn vararg)
      )
    , (3, callExpIn vararg)
    , (1, Lua.Paren . Lua.ann <$> multiValueExpIn vararg)
    ]

-- | A function call or method call (valid as a statement and under 'Paren').
callExpIn ∷ ∀ m. MonadGen m ⇒ VarargScope → m Lua.Exp
callExpIn vararg = do
  callee ← adjusted <$> Gen.small (expIn vararg)
  args ← Gen.list (Range.linear 0 2) (Gen.small (expIn vararg))
  Gen.choice
    [ pure (Lua.functionCall callee args)
    , (\n → Lua.methodCall callee n args) <$> name
    ]

{- | Strip a top-level 'Paren' for positions that consume exactly one value
(operator operands, prefix bases): the parser canonicalizes the paren away
there, so the generator must not produce it.
-}
adjusted ∷ Lua.Exp → Lua.Exp
adjusted (Lua.Paren (Lua.Ann e)) = e
adjusted e = e

multiValueExpIn ∷ ∀ m. MonadGen m ⇒ VarargScope → m Lua.Exp
multiValueExpIn vararg =
  Gen.frequency $
    [(4, callExpIn vararg)] <> [(1, pure Lua.Vararg) | vararg]

varIn ∷ ∀ m. MonadGen m ⇒ VarargScope → m Lua.Var
varIn vararg =
  Gen.recursiveFrequency
    [(3, Lua.VarName <$> name)]
    [ (1, Lua.VarField . Lua.ann . adjusted <$> Gen.small (expIn vararg) <*> name)
    ,
      ( 1
      , Lua.VarIndex . Lua.ann . adjusted
          <$> Gen.small (expIn vararg)
          <*> (Lua.ann <$> Gen.small (expIn vararg))
      )
    ]

tableRowIn
  ∷ ∀ m. MonadGen m ⇒ VarargScope → m (Lua.Annotated Lua.Comments Lua.TableRowF)
tableRowIn vararg =
  annotated $
    Gen.choice
      [ Lua.tableRowKV <$> Gen.small (expIn vararg) <*> Gen.small (expIn vararg)
      , Lua.tableRowNV <$> name <*> Gen.small (expIn vararg)
      , Lua.tableRowV <$> Gen.small (expIn vararg)
      ]

-- | Parameters first; the body's vararg scope is the function's own.
functionParts
  ∷ ∀ m
   . MonadGen m
  ⇒ m
      ( [Lua.Annotated Lua.Comments Lua.ParamF]
      , [Lua.Annotated Lua.Comments Lua.StatementF]
      )
functionParts = do
  named ← Gen.list (Range.linear 0 3) (Lua.ParamNamed <$> name)
  vararg ← Gen.frequency [(3, pure []), (1, pure [Lua.ParamVararg])]
  body ← blockIn (not (null vararg))
  pure (Lua.ann <$> (named <> vararg), body)

unaryOp ∷ ∀ m. MonadGen m ⇒ m Lua.UnaryOp
unaryOp = Gen.element [Lua.HashOp, Lua.Negate, Lua.LogicalNot]

-- | Lua 5.1 binary operators (no 5.3 floor-division/bitwise family).
binaryOp ∷ ∀ m. MonadGen m ⇒ m Lua.BinaryOp
binaryOp =
  Gen.element
    [ Lua.Or
    , Lua.And
    , Lua.LessThan
    , Lua.GreaterThan
    , Lua.LessThanOrEqualTo
    , Lua.GreaterThanOrEqualTo
    , Lua.NotEqualTo
    , Lua.EqualTo
    , Lua.Concat
    , Lua.Add
    , Lua.Sub
    , Lua.Mul
    , Lua.FloatDiv
    , Lua.Mod
    , Lua.Exp
    ]

name ∷ ∀ m. MonadGen m ⇒ m Name
name = do
  c ← Gen.element ['a' .. 'z']
  cs ← Gen.list (Range.linear 0 6) identChar
  let raw = toText (c : cs)
  -- Dodge reserved words constructively; the result is always a valid name.
  pure . Name.unsafeName $
    if raw `Set.member` Name.reserved then raw <> "_k" else raw
 where
  identChar = Gen.element (['a' .. 'z'] <> ['0' .. '9'] <> "_")

stringPayload ∷ ∀ m. MonadGen m ⇒ m Text
stringPayload =
  Gen.text (Range.linear 0 12) $
    Gen.element (['a' .. 'z'] <> ['A' .. 'Z'] <> ['0' .. '9'] <> " _.,!?+-*/")

--------------------------------------------------------------------------------
-- Evaluable expressions (semantic differential) -------------------------------

{- | A closed, runtime-error-free expression for the semantic differential in
'Language.PureScript.Backend.Lua.Differential.Spec': three sorts (number,
boolean, string) over constants, closed under the operators that cannot
raise at runtime on those sorts. Division\/modulo\/power by zero yield
inf\/nan deterministically, so they stay in. Excluded by construction:
arithmetic or comparison over mismatched sorts, concatenation of booleans
or nil, and any free variable.
-}
evaluableExp ∷ ∀ m. MonadGen m ⇒ m Lua.Exp
evaluableExp = Gen.choice [numExp, boolExp, strExp]

numExp ∷ ∀ m. MonadGen m ⇒ m Lua.Exp
numExp =
  Gen.recursiveFrequency
    [ (2, Lua.Integer <$> Gen.integral (Range.linear 0 1000))
    , (2, Lua.Float <$> Gen.double (Range.linearFrac 0 1000))
    ]
    [ (4, arithmetic)
    , (1, Lua.negate <$> numExp)
    , (1, Lua.hash <$> strExp)
    ]
 where
  arithmetic = do
    op ←
      Gen.element [Lua.Add, Lua.Sub, Lua.Mul, Lua.FloatDiv, Lua.Mod, Lua.Exp]
    Lua.binOp op <$> numExp <*> numExp

boolExp ∷ ∀ m. MonadGen m ⇒ m Lua.Exp
boolExp =
  Gen.recursiveFrequency
    [(2, Lua.Boolean <$> Gen.bool)]
    [ (2, comparison)
    , (2, equality)
    , (2, logical)
    , (1, Lua.logicalNot <$> boolExp)
    ]
 where
  comparison = do
    op ←
      Gen.element
        [ Lua.LessThan
        , Lua.GreaterThan
        , Lua.LessThanOrEqualTo
        , Lua.GreaterThanOrEqualTo
        ]
    -- Ordering is defined within one sort only: numbers or strings.
    Gen.choice
      [ Lua.binOp op <$> numExp <*> numExp
      , Lua.binOp op <$> strExp <*> strExp
      ]
  equality = do
    op ← Gen.element [Lua.EqualTo, Lua.NotEqualTo]
    Gen.choice
      [ Lua.binOp op <$> numExp <*> numExp
      , Lua.binOp op <$> strExp <*> strExp
      , Lua.binOp op <$> boolExp <*> boolExp
      ]
  logical = do
    op ← Gen.element [Lua.And, Lua.Or]
    Lua.binOp op <$> boolExp <*> boolExp

strExp ∷ ∀ m. MonadGen m ⇒ m Lua.Exp
strExp =
  Gen.recursiveFrequency
    [(2, Lua.String <$> stringPayload)]
    [
      ( 2
      , -- @..@ accepts strings and numbers (coercing the numbers).
        Lua.concat <$> concatOperand <*> concatOperand
      )
    ]
 where
  concatOperand = Gen.frequency [(2, strExp), (1, numExp)]
