{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Types where

import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Prettyprinter (Pretty)
import Prelude hiding
  ( and
  , concat
  , error
  , local
  , mod
  , negate
  , or
  , return
  )

type Chunk = [Statement]

newtype ChunkName = ChunkName Text
  deriving stock (Show)
  deriving newtype (Pretty)

{- | Comments attached to an AST node: each element is one comment verbatim,
including its markers (@--@ or @--[[ ... ]]@). The Lua parser
('Language.PureScript.Backend.Lua.Parser') fills these slots with the
comments preceding a node; the printer emits them back in front of the
node. Code-generated nodes carry no comments ('ann' annotates with
'mempty').
-}
type Comments = [Text]

type Annotated (a ∷ Type) (f ∷ Type → Type) = (a, f a)

pattern Ann ∷ b → (a, b)
pattern Ann fa ← (_ann, fa)
{-# COMPLETE Ann #-}

data ParamF a
  = ParamNamed Name
  | ParamUnused
  | ParamVararg

type Param = ParamF Comments

deriving stock instance Eq a ⇒ Eq (ParamF a)
deriving stock instance Ord a ⇒ Ord (ParamF a)
deriving stock instance Show a ⇒ Show (ParamF a)

data VarF a
  = VarName Name
  | VarIndex (Annotated a ExpF) (Annotated a ExpF)
  | VarField (Annotated a ExpF) Name

type Var = VarF Comments

deriving stock instance Eq a ⇒ Eq (VarF a)
deriving stock instance Ord a ⇒ Ord (VarF a)
deriving stock instance Show a ⇒ Show (VarF a)

data TableRowF ann
  = TableRowKV (Annotated ann ExpF) (Annotated ann ExpF)
  | TableRowNV Name (Annotated ann ExpF)
  | -- | Array-part row: @{ e1, e2 }@ assigns to consecutive integer keys.
    TableRowV (Annotated ann ExpF)

type TableRow = TableRowF Comments

deriving stock instance Eq a ⇒ Eq (TableRowF a)
deriving stock instance Ord a ⇒ Ord (TableRowF a)
deriving stock instance Show a ⇒ Show (TableRowF a)

data Precedence
  = PrecFunction
  | PrecOperation Natural
  | PrecPrefix
  | PrecTable
  | PrecAtom
  deriving stock (Show, Eq, Ord)

class HasPrecedence a where
  prec ∷ a → Precedence

class HasPrecedence a ⇒ HasSymbol a where
  sym ∷ a → Text

instance HasPrecedence Precedence where
  prec = id

data UnaryOp = HashOp | Negate | LogicalNot | BitwiseNot
  deriving stock (Show, Eq, Ord, Enum, Bounded)

instance HasPrecedence UnaryOp where
  prec =
    PrecOperation . \case
      HashOp → 11
      Negate → 11
      LogicalNot → 11
      BitwiseNot → 11

instance HasSymbol UnaryOp where
  sym = \case
    HashOp → "#"
    Negate → "-"
    LogicalNot → "not"
    BitwiseNot → "~"

data BinaryOp
  = Or
  | And
  | LessThan
  | GreaterThan
  | LessThanOrEqualTo
  | GreaterThanOrEqualTo
  | NotEqualTo
  | EqualTo
  | BitOr
  | BitXor
  | BitAnd
  | BitShiftRight
  | BitShiftLeft
  | Concat
  | Add
  | Sub
  | Mul
  | FloatDiv
  | FloorDiv
  | Mod
  | Exp
  deriving stock (Show, Eq, Ord, Enum, Bounded)

{- Note [Lua operator precedence]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Lua's operators bind at these levels (1 loosest, 12 tightest):

   1   or
   2   and
   3   <     >     <=    >=    ~=    ==
   4   |
   5   ~
   6   &
   7   <<    >>
   8   ..
   9   +     -
   10  *     /     //    %
   11  unary operators (not   #     -     ~)
   12  ^

The 'HasPrecedence' instances for 'BinaryOp' and 'UnaryOp' transcribe this
table into 'PrecOperation' levels. All operators are left-associative except
'..' and '^' ('assoc'); Lua has no chained-comparison sugar, so the
comparisons at level 3 are left-associative too (`a == b == c` parses as
`(a == b) == c`, comparing a boolean against `c`).

'Language.PureScript.Backend.Lua.Printer' always parenthesises an operand
looser than the enclosing operator. At the *same* precedence, it must also
parenthesise whichever side bare juxtaposition would re-associate away from
the AST: the right operand of a left-associative operator, or the left
operand of a right-associative one ('wrapPrec' vs 'wrapPrecGte'). Keep the
instances, this table, and 'assoc' in step, or the printer emits
wrongly-associated or over-bracketed expressions.
-}

{- | Whether @a `op` b `op` c@ parses as @(a `op` b) `op` c@ (left-associative)
or @a `op` (b `op` c)@ (right-associative). See Note [Lua operator
precedence].
-}
data Associativity = LeftAssoc | RightAssoc
  deriving stock (Show, Eq)

{- | Lua's only right-associative binary operators are '..' and '^'; every
other operator, including the non-chainable comparisons, is
left-associative.
-}
assoc ∷ BinaryOp → Associativity
assoc = \case
  Concat → RightAssoc
  Exp → RightAssoc
  _ → LeftAssoc

instance HasPrecedence BinaryOp where
  prec =
    PrecOperation . \case
      Or → 1
      And → 2
      LessThan → 3
      GreaterThan → 3
      LessThanOrEqualTo → 3
      GreaterThanOrEqualTo → 3
      NotEqualTo → 3
      EqualTo → 3
      BitOr → 4
      BitXor → 5
      BitAnd → 6
      BitShiftRight → 7
      BitShiftLeft → 7
      Concat → 8
      Add → 9
      Sub → 9
      Mul → 10
      FloatDiv → 10
      FloorDiv → 10
      Mod → 10
      Exp → 12

instance HasSymbol BinaryOp where
  sym = \case
    Or → "or"
    And → "and"
    LessThan → "<"
    GreaterThan → ">"
    LessThanOrEqualTo → "<="
    GreaterThanOrEqualTo → ">="
    NotEqualTo → "~="
    EqualTo → "=="
    BitOr → "|"
    BitXor → "~"
    BitAnd → "&"
    BitShiftRight → ">>"
    BitShiftLeft → "<<"
    Concat → ".."
    Add → "+"
    Sub → "-"
    Mul → "*"
    FloatDiv → "/"
    FloorDiv → "//"
    Mod → "%"
    Exp → "^"

{- | The string payload of a 'String' literal is kept in /source form/: the
text between the quotes of a double-quoted Lua string literal, escape
sequences unexpanded. The printer emits it verbatim between double quotes.
Keeping escapes unexpanded is load-bearing: a @\\255@ escape denotes a
single byte on the Lua 5.1 target, which decoded-and-reencoded Text could
not represent (see the Char quirk in docs/QUIRKS.md). Consequently the
payload must never contain a raw newline or an unescaped @"@ — the parser
normalizes both when converting from other quoting styles.
-}
data ExpF ann
  = Nil
  | Boolean Bool
  | Integer Integer
  | Float Double
  | String Text
  | Vararg
  | Function [Annotated ann ParamF] [Annotated ann StatementF]
  | TableCtor [Annotated ann TableRowF]
  | UnOp UnaryOp (Annotated ann ExpF)
  | BinOp BinaryOp (Annotated ann ExpF) (Annotated ann ExpF)
  | Var (Annotated ann VarF)
  | FunctionCall (Annotated ann ExpF) [Annotated ann ExpF]
  | MethodCall (Annotated ann ExpF) Name [Annotated ann ExpF]
  | {- | Explicit parentheses around a multi-valued expression (a call or
    '...'), which Lua adjusts to exactly one value. Grouping parens around
    single-valued expressions are not represented; the printer re-derives
    those from precedence.
    -}
    Paren (Annotated ann ExpF)

type Exp = ExpF Comments

deriving stock instance Eq a ⇒ Eq (ExpF a)
deriving stock instance Ord a ⇒ Ord (ExpF a)
deriving stock instance Show a ⇒ Show (ExpF a)

data StatementF ann
  = Assign
      (NonEmpty (Annotated ann VarF))
      -- ^ variables (multiple assignment assigns simultaneously)
      (NonEmpty (Annotated ann ExpF))
      -- ^ values
  | Local
      (NonEmpty Name)
      -- ^ declared names
      [Annotated ann ExpF]
      -- ^ initializers; @[]@ declares without a value
  | IfThenElse
      (Annotated ann ExpF)
      -- ^ predicate
      [Annotated ann StatementF]
      -- ^ then block
      [Annotated ann StatementF]
      -- ^ else block
  | Return [Annotated ann ExpF]
  | CallStatement (Annotated ann ExpF)
  | Do [Annotated ann StatementF]
  | While (Annotated ann ExpF) [Annotated ann StatementF]
  | Repeat [Annotated ann StatementF] (Annotated ann ExpF)
  | ForNum
      Name
      -- ^ loop variable
      (Annotated ann ExpF)
      -- ^ start
      (Annotated ann ExpF)
      -- ^ limit
      (Maybe (Annotated ann ExpF))
      -- ^ step
      [Annotated ann StatementF]
  | ForIn
      (NonEmpty Name)
      -- ^ loop variables
      (NonEmpty (Annotated ann ExpF))
      -- ^ iterator expressions
      [Annotated ann StatementF]
  | {- | @local function f() … end@; distinct from @local f = function() … end@
    in that @f@ is in scope inside the body (self-recursion).
    -}
    LocalFunction Name [Annotated ann ParamF] [Annotated ann StatementF]
  | Break

type Statement = StatementF Comments

deriving stock instance Eq a ⇒ Eq (StatementF a)
deriving stock instance Ord a ⇒ Ord (StatementF a)
deriving stock instance Show a ⇒ Show (StatementF a)

--------------------------------------------------------------------------------
-- Smarter constructors --------------------------------------------------------

ann ∷ f Comments → Annotated Comments f
ann f = ([], f)

unAnn ∷ Annotated a f → f a
unAnn = snd

var ∷ Var → Exp
var = Var . ann

assign ∷ Var → Exp → Statement
assign v e = Assign (pure (ann v)) (pure (ann e))

assignVar ∷ Name → Exp → Statement
assignVar name = assign (VarName name)

local ∷ Name → Maybe Exp → Statement
local name expr = Local (pure name) (ann <$> maybeToList expr)

local1 ∷ Name → Exp → Statement
local1 name expr = Local (pure name) [ann expr]

{- | @local n₁, …, nₖ = expr@ — bind several results of one multi-valued
expression at once.
-}
localN ∷ NonEmpty Name → Exp → Statement
localN names expr = Local names [ann expr]

local0 ∷ Name → Statement
local0 name = Local (pure name) []

ifThenElse ∷ Exp → Chunk → Chunk → Statement
ifThenElse i t e = IfThenElse (ann i) (ann <$> t) (ann <$> e)

return ∷ Exp → Statement
return e = Return [ann e]

-- | @return e₁, …, eₙ@ — a multi-value return.
returnN ∷ NonEmpty Exp → Statement
returnN es = Return (toList (ann <$> es))

chunkToExpression ∷ Chunk → Exp
chunkToExpression ss = functionCall (Function [] (ann <$> ss)) []

-- Expressions -----------------------------------------------------------------

table ∷ [TableRow] → Exp
table = TableCtor . fmap ann

varName ∷ Name → Exp
varName = Var . ann . VarName

varIndex ∷ Exp → Exp → Exp
varIndex e1 e2 = Var (ann (VarIndex (ann e1) (ann e2)))

varField ∷ Exp → Name → Exp
varField e n = Var (ann (VarField (ann e) n))

functionDef ∷ [Param] → Chunk → Exp
functionDef params body = Function (ann <$> params) (ann <$> body)

functionCall ∷ Exp → [Exp] → Exp
functionCall f args = FunctionCall (ann f) (ann <$> args)

methodCall ∷ Exp → Name → [Exp] → Exp
methodCall obj n args = MethodCall (ann obj) n (ann <$> args)

unOp ∷ UnaryOp → Exp → Exp
unOp op e = UnOp op (ann e)

binOp ∷ BinaryOp → Exp → Exp → Exp
binOp op e1 e2 = BinOp op (ann e1) (ann e2)

error ∷ Text → Exp
error msg = functionCall (varName [Lua.name|error|]) [String msg]

pun ∷ Name → TableRow
pun n = TableRowNV n (ann (varName n))

thunk ∷ Exp → Exp
thunk e = scope [Return [ann e]]

scope ∷ Chunk → Exp
scope body = functionCall (Function [] (ann <$> body)) []

-- Unary operators -------------------------------------------------------------

hash ∷ Exp → Exp
hash = UnOp HashOp . ann

negate ∷ Exp → Exp
negate = UnOp Negate . ann

logicalNot ∷ Exp → Exp
logicalNot = UnOp LogicalNot . ann

bitwiseNot ∷ Exp → Exp
bitwiseNot = UnOp BitwiseNot . ann

-- Binary operators ------------------------------------------------------------

or ∷ Exp → Exp → Exp
or e1 e2 = BinOp Or (ann e1) (ann e2)

and ∷ Exp → Exp → Exp
and e1 e2 = BinOp And (ann e1) (ann e2)

lessThan ∷ Exp → Exp → Exp
lessThan e1 e2 = BinOp LessThan (ann e1) (ann e2)

greaterThan ∷ Exp → Exp → Exp
greaterThan e1 e2 = BinOp GreaterThan (ann e1) (ann e2)

lessThanOrEqualTo ∷ Exp → Exp → Exp
lessThanOrEqualTo e1 e2 = BinOp LessThanOrEqualTo (ann e1) (ann e2)

greaterThanOrEqualTo ∷ Exp → Exp → Exp
greaterThanOrEqualTo e1 e2 = BinOp GreaterThanOrEqualTo (ann e1) (ann e2)

notEqualTo ∷ Exp → Exp → Exp
notEqualTo e1 e2 = BinOp NotEqualTo (ann e1) (ann e2)

equalTo ∷ Exp → Exp → Exp
equalTo e1 e2 = BinOp EqualTo (ann e1) (ann e2)

bitOr ∷ Exp → Exp → Exp
bitOr e1 e2 = BinOp BitOr (ann e1) (ann e2)

bitXor ∷ Exp → Exp → Exp
bitXor e1 e2 = BinOp BitXor (ann e1) (ann e2)

bitAnd ∷ Exp → Exp → Exp
bitAnd e1 e2 = BinOp BitAnd (ann e1) (ann e2)

bitShiftRight ∷ Exp → Exp → Exp
bitShiftRight e1 e2 = BinOp BitShiftRight (ann e1) (ann e2)

bitShiftLeft ∷ Exp → Exp → Exp
bitShiftLeft e1 e2 = BinOp BitShiftLeft (ann e1) (ann e2)

concat ∷ Exp → Exp → Exp
concat e1 e2 = BinOp Concat (ann e1) (ann e2)

add ∷ Exp → Exp → Exp
add e1 e2 = BinOp Add (ann e1) (ann e2)

sub ∷ Exp → Exp → Exp
sub e1 e2 = BinOp Sub (ann e1) (ann e2)

mul ∷ Exp → Exp → Exp
mul e1 e2 = BinOp Mul (ann e1) (ann e2)

floatDiv ∷ Exp → Exp → Exp
floatDiv e1 e2 = BinOp FloatDiv (ann e1) (ann e2)

floorDiv ∷ Exp → Exp → Exp
floorDiv e1 e2 = BinOp FloorDiv (ann e1) (ann e2)

mod ∷ Exp → Exp → Exp
mod e1 e2 = BinOp Mod (ann e1) (ann e2)

exponent ∷ Exp → Exp → Exp
exponent e1 e2 = BinOp Exp (ann e1) (ann e2)

-- Table Rows ------------------------------------------------------------------

tableRowKV ∷ Exp → Exp → TableRow
tableRowKV k v = TableRowKV (ann k) (ann v)

tableRowNV ∷ Name → Exp → TableRow
tableRowNV n v = TableRowNV n (ann v)

tableRowV ∷ Exp → TableRow
tableRowV = TableRowV . ann
