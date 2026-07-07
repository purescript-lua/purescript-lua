{-# LANGUAGE QuasiQuotes #-}

{- | A parser for the Lua 5.1 grammar producing the backend's own AST
('Language.PureScript.Backend.Lua.Types').

See Note [Parsing foreign Lua sources].
-}
module Language.PureScript.Backend.Lua.Parser
  ( parseChunk
  , parseExpression
  , unsafeParseStatements
  , ParseError
  , renderParseError

    -- * Internal
  , Parser
  ) where

import Data.Char qualified as Char
import Data.Set qualified as Set
import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Types hiding
  ( and
  , concat
  , error
  , exponent
  , local
  , mod
  , negate
  , or
  , return
  , var
  )
import Text.Megaparsec (Parsec, (<?>))
import Text.Megaparsec qualified as MP
import Text.Megaparsec.Char qualified as MP.Char

{- Note [Parsing foreign Lua sources]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is a complete parser for the Lua 5.1 grammar (the compilation target's
floor, see docs/QUIRKS.md), replacing the earlier lexical splitter that
extracted foreign export values as opaque text blobs. Values parsed into the
real AST are visible to every Lua-level optimization; a syntax error in a
foreign file is now a compile-time error rather than a luacheck/runtime one.

Three design points are worth spelling out:

  * /Comments ride in annotation slots./ The token-consuming primitives stash
    every comment they skip into backtracking-safe user state ('Parser' is
    'StateT' over 'Parsec', so a failed alternative restores pending
    comments). When a node that owns an annotation slot starts, it adopts the
    pending comments ('attachComments'/'mergeComments'). Comments thus attach
    to the closest following statement, table row, or expression — which is
    where FFI comments live. Comments trailing a block (before @end@) attach
    to the next node after the block, and comments at end of input are
    dropped: placement fidelity beyond "in front of the right node" is a
    non-goal, blank-line fidelity likewise.

  * /Strings are kept in source form./ A 'String' literal's payload is the
    text between double quotes with escapes unexpanded (see the Haddock on
    'ExpF'): decoding an escape like @\\255@ into Text and re-encoding would
    corrupt byte-oriented Lua strings. Single-quoted and long-bracket strings
    are converted to the double-quoted form (escaping @"@, backslash-newline,
    and for long brackets also @\\@ and raw newlines).

  * /Operator parsing mirrors lparser.c./ 'subexpr' is the precedence-climbing
    algorithm from Lua 5.1's own parser, with its left/right priority table
    ('binOpPriority'); this pins associativity (@..@ and @^@ right, all else
    left) and the unary-operator binding level to the reference
    implementation. Lua 5.3 operators recognised by the printer (@//@ and the
    bitwise family) are deliberately absent from the grammar.

Explicit parentheses around a call or @...@ are semantic in Lua (they adjust
a multi-value expression to exactly one value), so they parse into 'Paren';
parens around any single-valued expression are mere grouping and are dropped
— the printer re-derives them from precedence.

Known divergences from the reference parser (lua-5.1.5 lparser.c):

  * @goto@ is rejected as an identifier even though it became a keyword only
    in Lua 5.2. Deliberate: parsed FFI code and generated code (mangled
    against the same 'Name.reserved' set) share one output chunk, which must
    stay loadable on LuaJIT and Lua 5.2+, where @goto@ is reserved. See
    Note [Lua reserved words as foreign export keys] in
    "Language.PureScript.Backend.Lua.Key".

Everything else follows the reference, including its rejections: a line
break between a callee and the @(@ of its argument list is "ambiguous
syntax" ('callArgs', driven by 'newlineInGap'), @...@ outside a vararg
function is an error ('simpleExp' checks 'inVarargScope'), and 'withDepth'
caps parser recursion ('subexpr'/'block') the way LUAI_MAXCCALLS caps the
reference's C stack — at 500 rather than 200, since the cap only protects
the compiler from stack overflow on adversarial input, while the binding
limit for /generated/ nesting stays
'Language.PureScript.Backend.Lua.NestingCheck.nestingLimit' (180).
-}

type Parser = StateT ParserState (Parsec Void Text)

{- | Parser state, backtracking-safe by construction: 'Parser' is 'StateT'
/over/ 'Parsec', so a failed alternative restores the whole record.
-}
data ParserState = ParserState
  { pendingComments ∷ Comments
  -- ^ comments collected since the previous token, oldest first
  , newlineInGap ∷ Bool
  {- ^ whether a line break separates the previous token from the current
  one; drives the "ambiguous syntax" rejection in 'callArgs'
  -}
  , syntaxDepth ∷ Int
  -- ^ current 'withDepth' nesting level
  , inVarargScope ∷ Bool
  {- ^ whether @...@ is legal here: the innermost enclosing function has a
  @...@ parameter (the main chunk counts as a vararg function)
  -}
  }

initialParserState ∷ ParserState
initialParserState =
  ParserState
    { pendingComments = []
    , newlineInGap = False
    , syntaxDepth = 0
    , inVarargScope = True
    }

type ParseError = MP.ParseErrorBundle Text Void

renderParseError ∷ ParseError → String
renderParseError = MP.errorBundlePretty

--------------------------------------------------------------------------------
-- Entry points ----------------------------------------------------------------

-- | Parse a complete Lua 5.1 chunk (a block covering the whole input).
parseChunk
  ∷ FilePath
  → Text
  → Either ParseError [Annotated Comments StatementF]
parseChunk = MP.parse (evalStateT (sc *> block <* MP.eof) initialParserState)

-- | Parse a single Lua 5.1 expression covering the whole input.
parseExpression
  ∷ Text
  → Either ParseError (Annotated Comments ExpF)
parseExpression =
  MP.parse
    (evalStateT (sc *> expression <* MP.eof) initialParserState)
    "<expression>"

{- | Parse statements from a static (compiler-provided) Lua source, erroring
on a syntax error. For trusted fixture code only, never for user input.
-}
unsafeParseStatements ∷ HasCallStack ⇒ Text → [Statement]
unsafeParseStatements src =
  case parseChunk "<fixture>" src of
    Left err →
      error . toText $
        "Language.PureScript.Backend.Lua.Parser.unsafeParseStatements: "
          <> renderParseError err
    Right stats → unAnn <$> stats

--------------------------------------------------------------------------------
-- Comments in annotation slots ------------------------------------------------

-- | Pending comments collected since the previous token, oldest first.
takeComments ∷ Parser Comments
takeComments = state \s → (pendingComments s, s {pendingComments = []})

{- | Attach pending comments to the node about to be parsed. The parser is
one token past the comments at this point, so they belong to this node.
-}
attachComments ∷ Parser (f Comments) → Parser (Annotated Comments f)
attachComments p = do
  comments ← takeComments
  node ← p
  pure (comments, node)

-- | Like 'attachComments' for parsers already producing an annotated node.
mergeComments
  ∷ Parser (Annotated Comments f)
  → Parser (Annotated Comments f)
mergeComments p = do
  comments ← takeComments
  (comments', node) ← p
  pure (comments <> comments', node)

--------------------------------------------------------------------------------
-- Lexer -----------------------------------------------------------------------

{- | Skip whitespace and comments, stashing each comment into user state.
Also (re)computes 'newlineInGap': whether the skipped gap — including the
raw text of a long-bracket comment — contains a line break.
-}
sc ∷ Parser ()
sc = do
  modify' \s → s {newlineInGap = False}
  void $ MP.many (whitespace <|> comment)
 where
  whitespace = do
    gap ← MP.takeWhile1P (Just "white space") Char.isSpace
    when (hasNewline gap) markNewlineInGap
  comment = do
    (raw, _) ← MP.match do
      void (MP.Char.string "--")
      void (MP.try longBracket) <|> restOfLine
    when (hasNewline raw) markNewlineInGap
    modify' \s → s {pendingComments = pendingComments s <> [raw]}
  restOfLine = void $ MP.takeWhileP Nothing (\c → c /= '\n' && c /= '\r')
  hasNewline = Text.any \c → c == '\n' || c == '\r'
  markNewlineInGap = modify' \s → s {newlineInGap = True}

lexeme ∷ Parser a → Parser a
lexeme p = p <* sc

symbol ∷ Text → Parser ()
symbol s = lexeme (void (MP.Char.string s))

keyword ∷ Text → Parser ()
keyword k =
  lexeme . MP.try $
    MP.Char.string k *> MP.notFollowedBy (MP.satisfy isIdentRest)

-- | @=@ that is not @==@.
equals ∷ Parser ()
equals = lexeme . MP.try $ MP.Char.char '=' *> MP.notFollowedBy (MP.Char.char '=')

-- | @.@ that is not @..@ (concatenation) or @...@ (vararg).
dot ∷ Parser ()
dot = lexeme . MP.try $ MP.Char.char '.' *> MP.notFollowedBy (MP.Char.char '.')

-- | @[@ that is not the opening of a long-bracket string.
openBracket ∷ Parser ()
openBracket =
  lexeme . MP.try $
    MP.Char.char '['
      *> MP.notFollowedBy (MP.satisfy \c → c == '[' || c == '=')

{- | Cap on 'withDepth' nesting. Chosen above the emitter's own
'Language.PureScript.Backend.Lua.NestingCheck.nestingLimit' (180) and above
the reference parser's LUAI_MAXCCALLS (200): this cap exists only to turn a
stack overflow on adversarially nested input into a parse error, not to
enforce the target's runtime limits.
-}
syntaxNestingLimit ∷ Int
syntaxNestingLimit = 500

{- | Run a parser one syntax level deeper, failing once the depth exceeds
'syntaxNestingLimit'. Wraps the two recursions whose depth is driven by
input nesting: 'subexpr' (parenthesised\/unary\/right-associative chains)
and 'block' (statement bodies). On failure the 'StateT' backtracking
restores the depth by itself.
-}
withDepth ∷ Parser a → Parser a
withDepth p = do
  depth ← gets syntaxDepth
  when (depth >= syntaxNestingLimit) $
    fail
      ("nesting too deep: more than " <> show syntaxNestingLimit <> " syntax levels")
  modify' \s → s {syntaxDepth = depth + 1}
  a ← p
  modify' \s → s {syntaxDepth = depth}
  pure a

isIdentStart ∷ Char → Bool
isIdentStart c = Char.isAlpha c || c == '_'

isIdentRest ∷ Char → Bool
isIdentRest c = Char.isAlphaNum c || c == '_'

-- | An identifier that is not a reserved word.
identifier ∷ Parser Name
identifier = lexeme . MP.try $ do
  c ← MP.satisfy isIdentStart <?> "identifier"
  rest ← MP.takeWhileP Nothing isIdentRest
  let txt = Text.cons c rest
  if txt `Set.member` Name.reserved
    then fail ("unexpected keyword " <> show txt)
    else maybe (fail ("invalid identifier " <> show txt)) pure (Name.fromText txt)

--------------------------------------------------------------------------------
-- Literals --------------------------------------------------------------------

{- | Lua 5.1 numerals: decimal integers, decimal floats (fraction and\/or
exponent, including forms like @.5@ and @1.@), and hexadecimal integers.
-}
numberLit ∷ Parser (ExpF Comments)
numberLit =
  lexeme $
    (MP.try hexadecimal <|> MP.try decimal)
      <* MP.notFollowedBy (MP.satisfy isIdentRest)
 where
  hexadecimal ∷ Parser (ExpF Comments)
  hexadecimal = do
    void (MP.Char.string "0x" <|> MP.Char.string "0X")
    digits ← MP.takeWhile1P (Just "hexadecimal digit") Char.isHexDigit
    pure . Integer $
      Text.foldl' (\acc c → acc * 16 + toInteger (Char.digitToInt c)) 0 digits

  decimal ∷ Parser (ExpF Comments)
  decimal = do
    (txt, isFloat) ← MP.match do
      intPart ← MP.takeWhileP Nothing Char.isDigit
      fracPart ← MP.optional (MP.Char.char '.' *> MP.takeWhileP Nothing Char.isDigit)
      guard (not (Text.null intPart) || not (all Text.null fracPart))
      expoPart ← MP.optional . MP.try $ do
        void (MP.satisfy \c → c == 'e' || c == 'E')
        void (MP.optional (MP.satisfy \c → c == '+' || c == '-'))
        void (MP.takeWhile1P (Just "exponent digit") Char.isDigit)
      pure (isJust fracPart || isJust expoPart)
    if isFloat
      then Float <$> readDouble txt
      else Integer <$> readInteger txt

  readDouble ∷ Text → Parser Double
  readDouble txt =
    -- Haskell's Read is stricter than Lua about a bare dot: pad "1." / ".5"
    -- (and "1.e5") into forms it accepts.
    let (mantissa, expo) = Text.break (\c → c == 'e' || c == 'E') txt
        padded =
          mantissa
            & (\m → if "." `Text.isPrefixOf` m then "0" <> m else m)
            & (\m → if "." `Text.isSuffixOf` m then m <> "0" else m)
     in maybe (fail ("malformed number " <> show txt)) pure $
          readMaybe (toString (padded <> expo))

  readInteger ∷ Text → Parser Integer
  readInteger txt =
    maybe (fail ("malformed number " <> show txt)) pure $
      readMaybe (toString txt)

{- | A Lua 5.1 string literal, converted to /double-quoted source form/
(see the Haddock on 'ExpF').
-}
stringLit ∷ Parser (ExpF Comments)
stringLit =
  lexeme $
    String
      <$> ( shortString '"'
              <|> shortString '\''
              <|> (escapeRawText . dropLeadingNewline <$> MP.try longBracket)
          )

{- | The body of a short string literal. Escape sequences stay unexpanded;
an escaped newline is normalized to @\\n@, and when converting from a
single-quoted literal every unescaped @"@ becomes @\\"@.
-}
shortString ∷ Char → Parser Text
shortString quote = MP.Char.char quote *> body
 where
  body = do
    chunk ←
      MP.takeWhileP Nothing \c →
        c /= quote && c /= '\\' && c /= '\n' && c /= '\r'
    let converted
          | quote == '\'' = Text.replace "\"" "\\\"" chunk
          | otherwise = chunk
    MP.choice
      [ MP.Char.char quote $> converted
      , do
          void (MP.Char.char '\\')
          c ← MP.anySingle <?> "escape sequence"
          escaped ← case c of
            '\n' → MP.optional (MP.Char.char '\r') $> "\\n"
            '\r' → MP.optional (MP.Char.char '\n') $> "\\n"
            _ → pure (Text.pack ['\\', c])
          rest ← body
          pure (converted <> escaped <> rest)
      , fail "unterminated string"
      ]

{- | A long-bracket payload @[==[ ... ]==]@ (any level), returning the raw
content. Backtracks if the input does not open a long bracket.
-}
longBracket ∷ Parser Text
longBracket = do
  level ← MP.try do
    void (MP.Char.char '[')
    eqs ← MP.takeWhileP Nothing (== '=')
    void (MP.Char.char '[')
    pure eqs
  let close = "]" <> level <> "]"
  let go acc = do
        chunk ← MP.takeWhileP Nothing (/= ']')
        MP.choice
          [ MP.Char.string close $> (acc <> chunk)
          , MP.Char.char ']' *> go (acc <> chunk <> "]")
          ]
  go ""

-- | Lua drops a newline immediately following a long bracket's opener.
dropLeadingNewline ∷ Text → Text
dropLeadingNewline t =
  fromMaybe t $
    Text.stripPrefix "\r\n" t
      <|> Text.stripPrefix "\n\r" t
      <|> Text.stripPrefix "\n" t
      <|> Text.stripPrefix "\r" t

-- | Escape raw (long-bracket) content into double-quoted source form.
escapeRawText ∷ Text → Text
escapeRawText = Text.concatMap \case
  '\\' → "\\\\"
  '"' → "\\\""
  '\n' → "\\n"
  '\r' → "\\r"
  c → Text.singleton c

--------------------------------------------------------------------------------
-- Expressions -----------------------------------------------------------------

type AnnExp = Annotated Comments ExpF

{- | In a position that consumes exactly one value — an operator operand or
a prefix base for indexing\/field access\/calls — the multi-value
adjustment of explicit parens is a no-op, so @(f()).x@, @#(...)@ and the
like canonicalize to the paren-free form. This also makes @parse . print@
the identity: the printer parenthesizes unary operands and non-name
prefixes for readability.
-}
unparen ∷ AnnExp → AnnExp
unparen (comments, Paren (comments', inner)) = (comments <> comments', inner)
unparen e = e

expression ∷ Parser AnnExp
expression = subexpr 0

explist1 ∷ Parser (NonEmpty AnnExp)
explist1 = do
  e ← expression
  es ← MP.many (symbol "," *> expression)
  pure (e :| es)

{- | Precedence climbing, transcribed from @subexpr@ in Lua 5.1's lparser.c
(see Note [Parsing foreign Lua sources]). Left-associative chains stay in
'loop' at one depth; parens, unary operators, and right-associative
operators recurse under 'withDepth'.
-}
subexpr ∷ Int → Parser AnnExp
subexpr limit = withDepth (prefix >>= loop)
 where
  prefix =
    mergeComments $
      MP.choice
        [ do
            op ← unaryOp
            e ← subexpr unaryPriority
            pure ([], UnOp op (unparen e))
        , simpleExp
        ]

  loop left =
    MP.choice
      [ do
          op ← MP.try do
            op ← binaryOp
            guard (fst (binOpPriority op) > limit)
            pure op
          right ← subexpr (snd (binOpPriority op))
          loop ([], BinOp op left right)
      , pure left
      ]

unaryPriority ∷ Int
unaryPriority = 8

-- | (left, right) binding priorities from Lua 5.1's lparser.c.
binOpPriority ∷ BinaryOp → (Int, Int)
binOpPriority = \case
  Or → (1, 1)
  And → (2, 2)
  LessThan → (3, 3)
  GreaterThan → (3, 3)
  LessThanOrEqualTo → (3, 3)
  GreaterThanOrEqualTo → (3, 3)
  NotEqualTo → (3, 3)
  EqualTo → (3, 3)
  Concat → (5, 4) -- right-associative
  Add → (6, 6)
  Sub → (6, 6)
  Mul → (7, 7)
  FloatDiv → (7, 7)
  Mod → (7, 7)
  Exp → (10, 9) -- right-associative
  -- Not part of the Lua 5.1 grammar; unreachable from 'binaryOp'.
  BitOr → (4, 4)
  BitXor → (5, 5)
  BitAnd → (6, 6)
  BitShiftRight → (7, 7)
  BitShiftLeft → (7, 7)
  FloorDiv → (7, 7)

unaryOp ∷ Parser UnaryOp
unaryOp =
  MP.choice
    [ LogicalNot <$ keyword "not"
    , HashOp <$ symbol "#"
    , Negate <$ minus
    ]

-- | @-@ that is not the @--@ comment opener.
minus ∷ Parser ()
minus = lexeme . MP.try $ MP.Char.char '-' *> MP.notFollowedBy (MP.Char.char '-')

binaryOp ∷ Parser BinaryOp
binaryOp =
  MP.choice
    [ Add <$ symbol "+"
    , Sub <$ minus
    , Mul <$ symbol "*"
    , FloatDiv <$ symbol "/"
    , Mod <$ symbol "%"
    , Exp <$ symbol "^"
    , Concat <$ concatOp
    , EqualTo <$ symbol "=="
    , NotEqualTo <$ symbol "~="
    , LessThanOrEqualTo <$ MP.try (symbol "<=")
    , LessThan <$ symbol "<"
    , GreaterThanOrEqualTo <$ MP.try (symbol ">=")
    , GreaterThan <$ symbol ">"
    , And <$ keyword "and"
    , Or <$ keyword "or"
    ]
 where
  -- @..@ that is not the @...@ vararg.
  concatOp =
    lexeme . MP.try $
      MP.Char.string ".." *> MP.notFollowedBy (MP.Char.char '.')

simpleExp ∷ Parser AnnExp
simpleExp =
  mergeComments . MP.choice $
    [ plain (Nil <$ keyword "nil")
    , plain (Boolean True <$ keyword "true")
    , plain (Boolean False <$ keyword "false")
    , plain do
        MP.try (symbol "...")
        varargScope ← gets inVarargScope
        unless varargScope $
          fail "cannot use '...' outside a vararg function"
        pure Vararg
    , plain numberLit
    , plain stringLit
    , plain (TableCtor <$> tableCtor)
    , plain functionExp
    , suffixedExp
    ]
 where
  plain ∷ Parser (ExpF Comments) → Parser AnnExp
  plain = fmap ([],)

functionExp ∷ Parser (ExpF Comments)
functionExp = do
  keyword "function"
  (params, body) ← funcBody
  pure (Function params body)

{- | @funcbody ::= '(' [parlist] ')' block end@ with
@parlist ::= namelist [',' '...'] | '...'@.
-}
funcBody
  ∷ Parser ([Annotated Comments ParamF], [Annotated Comments StatementF])
funcBody = do
  symbol "("
  params ← param `MP.sepBy` symbol ","
  symbol ")"
  let isVararg = (== ParamVararg) . unAnn
  case reverse params of
    _last : earlier
      | any isVararg earlier →
          fail "'...' must be the last parameter"
    _ → pass
  -- The body's vararg scope is this function's own, not the enclosing one.
  outerVarargScope ← gets inVarargScope
  modify' \s → s {inVarargScope = any isVararg params}
  body ← block
  keyword "end"
  modify' \s → s {inVarargScope = outerVarargScope}
  pure (params, body)
 where
  param ∷ Parser (Annotated Comments ParamF)
  param =
    ([],)
      <$> MP.choice
        [ ParamVararg <$ MP.try (symbol "...")
        , ParamNamed <$> identifier
        ]

{- | @prefixexp@\/@functioncall@\/@var@: a primary expression (name or
parenthesised expression) followed by any number of index, field, method
call, and call suffixes.
-}
suffixedExp ∷ Parser AnnExp
suffixedExp = primaryExp >>= suffixes
 where
  primaryExp ∷ Parser AnnExp
  primaryExp =
    MP.choice
      [ ([],) . Var . ([],) . VarName <$> identifier
      , do
          symbol "("
          e@(comments, inner) ← expression
          symbol ")"
          pure case inner of
            -- Parens adjust a multi-valued expression to one value.
            FunctionCall {} → ([], Paren e)
            MethodCall {} → ([], Paren e)
            Vararg → ([], Paren e)
            -- Around a single-valued expression they are mere grouping.
            _ → (comments, inner)
      ]

  suffixes ∷ AnnExp → Parser AnnExp
  suffixes base =
    MP.choice
      [ do
          dot
          n ← identifier
          suffixes ([], Var ([], VarField base' n))
      , do
          openBracket
          k ← expression
          symbol "]"
          suffixes ([], Var ([], VarIndex base' k))
      , do
          symbol ":"
          n ← identifier
          args ← callArgs
          suffixes ([], MethodCall base' n args)
      , do
          args ← callArgs
          suffixes ([], FunctionCall base' args)
      , pure base
      ]
   where
    -- See 'unparen': in prefix position the adjustment is a no-op.
    base' = unparen base

{- | @args ::= '(' [explist] ')' | tableconstructor | String@

A line break between the callee and @(@ is rejected the way the reference
parser rejects it ("ambiguous syntax"): it cannot tell a call from a new
statement that starts with a parenthesised expression. The flag is sampled
/before/ 'symbol' (whose trailing 'sc' resets it), and the failure happens
/after/ @(@ is consumed: a consuming failure commits the error, whereas
failing first would make 'suffixes' silently take its no-suffix branch and
misread the input as two statements. String and table arguments stay legal
across a line break — the reference accepts those.
-}
callArgs ∷ Parser [AnnExp]
callArgs =
  MP.choice
    [ do
        gapBeforeParen ← gets newlineInGap
        symbol "("
        when gapBeforeParen $
          fail . mconcat $
            [ "ambiguous syntax (function call x new statement): "
            , "terminate the previous statement with ';' "
            , "or keep '(' on the same line as the callee"
            ]
        args ← expression `MP.sepBy` symbol ","
        symbol ")"
        pure args
    , one . ([],) . TableCtor <$> tableCtor
    , one . ([],) <$> lexeme (String <$> shortStringOrLong)
    ]
 where
  shortStringOrLong =
    shortString '"'
      <|> shortString '\''
      <|> (escapeRawText . dropLeadingNewline <$> MP.try longBracket)

{- | @tableconstructor ::= '{' [fieldlist] '}'@ where fields are separated
by @,@ or @;@ with an optional trailing separator.
-}
tableCtor ∷ Parser [Annotated Comments TableRowF]
tableCtor = do
  symbol "{"
  rows ← row `MP.sepEndBy` fieldSep
  symbol "}"
  pure rows
 where
  fieldSep = symbol "," <|> symbol ";"
  row =
    attachComments $
      MP.choice
        [ do
            openBracket
            k ← expression
            symbol "]"
            equals
            TableRowKV k <$> expression
        , MP.try do
            n ← identifier
            equals
            TableRowNV n <$> expression
        , TableRowV <$> expression
        ]

--------------------------------------------------------------------------------
-- Statements ------------------------------------------------------------------

type AnnStat = Annotated Comments StatementF

{- | @block ::= {stat [';']} [laststat [';']]@ — @return@\/@break@ may only
close a block.
-}
block ∷ Parser [AnnStat]
block = withDepth do
  stats ← MP.many (statement <* MP.optional (symbol ";"))
  final ← MP.optional (lastStatement <* MP.optional (symbol ";"))
  pure (stats <> maybeToList final)

lastStatement ∷ Parser AnnStat
lastStatement =
  attachComments . MP.choice $
    [ Break <$ keyword "break"
    , do
        keyword "return"
        values ← MP.optional explist1
        pure (Return (maybe [] toList values))
    ]

statement ∷ Parser AnnStat
statement =
  attachComments . MP.choice $
    [ doStat
    , whileStat
    , repeatStat
    , ifStat
    , forStat
    , functionStat
    , localStat
    , exprStat
    ]

doStat ∷ Parser (StatementF Comments)
doStat = do
  keyword "do"
  body ← block
  keyword "end"
  pure (Do body)

whileStat ∷ Parser (StatementF Comments)
whileStat = do
  keyword "while"
  predicate ← expression
  keyword "do"
  body ← block
  keyword "end"
  pure (While predicate body)

repeatStat ∷ Parser (StatementF Comments)
repeatStat = do
  keyword "repeat"
  body ← block
  keyword "until"
  Repeat body <$> expression

{- | @elseif@ chains parse into a nested 'IfThenElse' in the else-slot; the
printer re-sugars comment-free chains back to @elseif@. The clauses are
collected iteratively (the reference parser loops over @elseif@ the same
way) and folded into the nested shape afterwards, so a long ladder costs no
parser recursion depth.
-}
ifStat ∷ Parser (StatementF Comments)
ifStat = do
  keyword "if"
  predicate ← expression
  keyword "then"
  thenBlock ← block
  IfThenElse predicate thenBlock <$> elseTail []
 where
  -- Clauses accumulate most-recent-first; 'nestClauses' wraps them around
  -- the final else-block from the innermost @elseif@ outwards.
  elseTail ∷ [(Comments, AnnExp, [AnnStat])] → Parser [AnnStat]
  elseTail clauses =
    MP.choice
      [ keyword "end" $> nestClauses []
      , nestClauses <$> (keyword "else" *> block <* keyword "end")
      , do
          comments ← takeComments
          keyword "elseif"
          predicate ← expression
          keyword "then"
          thenBlock ← block
          elseTail ((comments, predicate, thenBlock) : clauses)
      ]
   where
    nestClauses ∷ [AnnStat] → [AnnStat]
    nestClauses = flip (foldl' nest) clauses
    nest ∷ [AnnStat] → (Comments, AnnExp, [AnnStat]) → [AnnStat]
    nest inner (comments, predicate, thenBlock) =
      [(comments, IfThenElse predicate thenBlock inner)]

forStat ∷ Parser (StatementF Comments)
forStat = do
  keyword "for"
  name ← identifier
  numericFor name <|> genericFor name
 where
  numericFor name = do
    equals
    start ← expression
    symbol ","
    limit ← expression
    step ← MP.optional (symbol "," *> expression)
    keyword "do"
    body ← block
    keyword "end"
    pure (ForNum name start limit step body)

  genericFor name = do
    names ← MP.many (symbol "," *> identifier)
    keyword "in"
    exprs ← explist1
    keyword "do"
    body ← block
    keyword "end"
    pure (ForIn (name :| names) exprs body)

{- | @function funcname funcbody@ desugars to the assignment the Lua manual
defines it as; a method name adds the implicit @self@ parameter.
-}
functionStat ∷ Parser (StatementF Comments)
functionStat = do
  keyword "function"
  root ← identifier
  fields ← MP.many (dot *> identifier)
  method ← MP.optional (symbol ":" *> identifier)
  (params, body) ← funcBody
  let selfParam ∷ Annotated Comments ParamF
      selfParam = ([], ParamNamed [Name.name|self|])
      params' = maybe params (const (selfParam : params)) method
      target =
        foldl'
          (\v field → VarField ([], Var ([], v)) field)
          (VarName root)
          (fields <> maybeToList method)
  pure (Assign (one ([], target)) (one ([], Function params' body)))

localStat ∷ Parser (StatementF Comments)
localStat = do
  keyword "local"
  localFunction <|> localNames
 where
  localFunction = do
    keyword "function"
    name ← identifier
    (params, body) ← funcBody
    pure (LocalFunction name params body)

  localNames = do
    name ← identifier
    names ← MP.many (symbol "," *> identifier)
    values ← MP.optional (equals *> explist1)
    pure (Local (name :| names) (maybe [] toList values))

{- | The @varlist '=' explist@ / @functioncall@ statements, disambiguated the
way Lua's parser does it: parse one suffixed expression, then decide by the
next token.
-}
exprStat ∷ Parser (StatementF Comments)
exprStat = do
  e ← suffixedExp
  MP.choice
    [ do
        vars ← MP.many (symbol "," *> suffixedExp)
        equals
        values ← explist1
        variables ← traverse toVar (e :| vars)
        pure (Assign variables values)
    , case e of
        (_, FunctionCall {}) → pure (CallStatement e)
        (_, MethodCall {}) → pure (CallStatement e)
        _ → fail "unexpected expression in statement position"
    ]
 where
  toVar ∷ AnnExp → Parser (Annotated Comments VarF)
  toVar = \case
    (comments, Var (comments', v)) → pure (comments <> comments', v)
    _ → fail "expected a variable on the left of '='"
