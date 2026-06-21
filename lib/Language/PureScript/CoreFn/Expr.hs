-- | The core functional representation
module Language.PureScript.CoreFn.Expr where

import Control.Arrow ((***))
import Language.PureScript.Names
import Language.PureScript.PSString (PSString)

-- | Data type for expressions and terms
data Expr a
  = -- | literal value
    Literal a (Literal (Expr a))
  | -- | data constructor (type name, constructor name, field names)
    Constructor a (ProperName 'TypeName) (ProperName 'ConstructorName) [Ident]
  | -- | record property accessor
    Accessor a PSString (Expr a)
  | -- | Partial record update
    ObjectUpdate a (Expr a) [(PSString, Expr a)]
  | -- | Function introduction
    Abs a Ident (Expr a)
  | -- | Function application
    App a (Expr a) (Expr a)
  | -- | Variable
    Var a (Qualified Ident)
  | -- | Case expression
    Case a [Expr a] [CaseAlternative a]
  | -- | Let binding
    Let a [Bind a] (Expr a)
  deriving stock (Eq, Ord, Show, Functor)

data Binder a
  = -- | Wildcard binder
    NullBinder a
  | -- | Binder which matches a literal value
    LiteralBinder a (Literal (Binder a))
  | -- | Binder which binds an identifier
    VarBinder a Ident
  | -- | Binder which matches data constructor
    ConstructorBinder
      a
      (Qualified (ProperName 'TypeName))
      (Qualified (ProperName 'ConstructorName))
      [Binder a]
  | -- A binder which binds its input to an identifier
    NamedBinder a Ident (Binder a)
  deriving stock (Eq, Ord, Show, Functor)

extractBinderAnn ∷ Binder a → a
extractBinderAnn = \case
  NullBinder a → a
  LiteralBinder a _ → a
  VarBinder a _ → a
  ConstructorBinder a _ _ _ → a
  NamedBinder a _ _ → a

-- | A let or module binding.
data Bind a
  = -- | Non-recursive binding for a single value
    NonRec a Ident (Expr a)
  | -- | Mutually recursive binding group for several values
    Rec [((a, Ident), Expr a)]
  deriving stock (Eq, Ord, Show, Functor)

{- |
A guard is just a literalBool-valued expression
that appears alongside a set of binders
-}
type Guard a = Expr a

-- | An alternative in a case statement
data CaseAlternative a = CaseAlternative
  { caseAlternativeBinders ∷ [Binder a]
  -- ^ A collection of binders with which to match the inputs
  , caseAlternativeResult ∷ Either [(Guard a, Expr a)] (Expr a)
  -- ^ The result expression or a collect of guarded expressions
  }
  deriving stock (Eq, Ord, Show)

instance Functor CaseAlternative where
  fmap f (CaseAlternative cabs car) =
    CaseAlternative
      (fmap (fmap f) cabs)
      (either (Left . fmap (fmap f *** fmap f)) (Right . fmap f) car)

{- | Data type for literal values.
Parameterised so it can be used for Exprs and Binders.
-}
data Literal a
  = -- | A numeric literal
    NumericLiteral (Either Integer Double)
  | -- | A string literal
    StringLiteral PSString
  | -- | A character literal
    CharLiteral Char
  | -- | A literalBool literal
    BooleanLiteral Bool
  | -- | An array literal
    ArrayLiteral [a]
  | -- | An object literal
    ObjectLiteral [(PSString, a)]
  deriving stock (Eq, Ord, Show, Functor)

-- | Extract the annotation from a term
extractAnn ∷ Expr a → a
extractAnn = \case
  Literal a _ → a
  Constructor a _ _ _ → a
  Accessor a _ _ → a
  ObjectUpdate a _ _ → a
  Abs a _ _ → a
  App a _ _ → a
  Var a _ → a
  Case a _ _ → a
  Let a _ _ → a

-- | Modify the annotation on a term
modifyAnn ∷ (a → a) → Expr a → Expr a
modifyAnn f = \case
  Literal a b → Literal (f a) b
  Constructor a b c d → Constructor (f a) b c d
  Accessor a b c → Accessor (f a) b c
  ObjectUpdate a b c → ObjectUpdate (f a) b c
  Abs a b c → Abs (f a) b c
  App a b c → App (f a) b c
  Var a b → Var (f a) b
  Case a b c → Case (f a) b c
  Let a b c → Let (f a) b c
