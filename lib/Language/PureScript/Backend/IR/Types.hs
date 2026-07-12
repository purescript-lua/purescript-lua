{-# LANGUAGE TemplateHaskell #-}

module Language.PureScript.Backend.IR.Types where

import Control.Lens
  ( Prism'
  , Traversal'
  , foldMapOf
  , makePrisms
  , prism'
  , rewriteMOf
  , traverseOf
  )
import Control.Monad.Writer.CPS (runWriterT, tell)
import Data.Deriving (deriveEq1, deriveOrd1)
import Data.Map qualified as Map
import Data.MonoidMap (MonoidMap)
import Data.MonoidMap qualified as MMap
import Data.Set qualified as Set
import Data.Traversable (mapAccumM)
import Language.PureScript.Backend.IR.Inliner qualified as Inliner
import Language.PureScript.Backend.IR.Names
  ( CtorName (renderCtorName)
  , FieldName
  , ModuleName (ModuleName)
  , Name (Name, nameToText)
  , PropName
  , Qualified (..)
  , TyName (renderTyName)
  , discardName
  , runModuleName
  )
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName)
import Prelude hiding (show)

type Ann = Maybe Inliner.Annotation

noAnn ∷ Ann
noAnn = Nothing

type Exp = RawExp Ann

data Module = Module
  { moduleName ∷ ModuleName
  , moduleBindings ∷ [Binding]
  , moduleImports ∷ [ModuleName]
  , moduleExports ∷ [Name]
  , moduleReExports ∷ Map ModuleName [Name]
  , moduleForeigns ∷ [(Ann, Name)]
  , modulePath ∷ FilePath
  }

data Grouping a = Standalone a | RecursiveGroup (NonEmpty a)
  deriving stock (Show, Eq, Ord, Functor, Foldable, Traversable)

listGrouping ∷ Grouping a → [a]
listGrouping = \case
  Standalone a → [a]
  RecursiveGroup as → toList as

type Binding = Grouping (Ann, Name, Exp)

bindingNames ∷ Grouping (ann, name, exp) → [name]
bindingNames = (\(_ann, name, _exp) → name) <<$>> listGrouping

bindingExprs ∷ Grouping (name, RawExp ann) → [RawExp ann]
bindingExprs = fmap snd . listGrouping

newtype Info = Info {refsFree ∷ Map (Qualified Name) Natural}

instance Semigroup Info where
  Info a <> Info b = Info (Map.unionWith (+) a b)

instance Monoid Info where
  mempty = Info mempty

data AlgebraicType = SumType | ProductType
  deriving stock (Generic, Eq, Ord, Show, Enum, Bounded)

data Parameter ann = ParamUnused ann | ParamNamed ann Name
  deriving stock (Show, Eq, Ord, Functor, Foldable, Traversable)

paramName ∷ Parameter ann → Maybe Name
paramName (ParamUnused _ann) = Nothing
paramName (ParamNamed _ann name) = Just name

{- | A binary primitive operation, defined as the Lua operator of the same
name so that lowering is the identity (see Note [IR primops]). Every
operator here is binary; the sole unary primop, logical @not@, is its own
'PrimNot' node.
-}
data PrimOp
  = -- | @+@
    PrimAdd
  | -- | @-@
    PrimSub
  | -- | @*@
    PrimMul
  | -- | @/@ (Lua float division)
    PrimDiv
  | -- | @%@ (Lua 5.1 modulo, sign of the divisor)
    PrimMod
  | -- | @..@ (string concatenation)
    PrimConcat
  | -- | @<@
    PrimLt
  | -- | @<=@
    PrimLe
  | -- | @>@
    PrimGt
  | -- | @>=@
    PrimGe
  | -- | @and@
    PrimAnd
  | -- | @or@
    PrimOr
  deriving stock (Generic, Eq, Ord, Show, Enum, Bounded)

{- Note [IR primops]
~~~~~~~~~~~~~~~~~~~~~
'PrimBinOp' and 'PrimNot' are the pure Lua scalar operators lifted into
the IR (issue #178). Their reason to exist is that hot polymorphic code
bottoms out in opaque curried foreigns — @intAdd@, @ordIntImpl@,
@refEq@, @boolConj@ — that the optimizer cannot see through: to the IR a
foreign body is text. Lifting that text's pure return-tree subset to
these nodes (see the foreign lifter,
"Language.PureScript.Backend.Lua.ForeignLift") lets the existing rules —
beta reduction, case-of-known-constructor (issue #177), inlining, and
the constant folding below — finish the specialization, collapsing a
dictionary chain like @greaterThanOrEq(ordInt)(a)(b)@ to @not (a < b)@.

Each node /is/ the corresponding Lua operator, so two directions are
correct by construction:

  * lowering ('Language.PureScript.Backend.Lua.fromIR') maps the node
    straight onto the Lua 'Language.PureScript.Backend.Lua.Types.BinOp' /
    'Language.PureScript.Backend.Lua.Types.UnOp' of the same name — an
    identity;
  * lifting maps that same Lua operator onto the node — semantics
    preserving because it is the inverse of lowering.

Equality is deliberately /not/ a primop: it already exists as the 'Eq'
node, and the lifter maps @==@ onto it (and @~=@ onto @not (a == b)@).

The correctness burden falls only on rules that /compute/ over primops —
the constant folding in
"Language.PureScript.Backend.IR.Optimizer" — which must follow the
target's semantics (Lua 5.1: every number is an IEEE double), not the
host's. See the folding rules there for the per-operator caveats
(integer range, division by zero, the modulo sign, concat typing).
-}

data RawExp ann
  = LiteralInt ann Integer
  | LiteralFloat ann Double
  | LiteralString ann Text
  | LiteralChar ann Char
  | LiteralBool ann Bool
  | LiteralArray ann [RawExp ann]
  | LiteralObject ann [(PropName, RawExp ann)]
  | Ctor ann AlgebraicType ModuleName TyName CtorName [FieldName]
  | ReflectCtor ann (RawExp ann)
  | Eq ann (RawExp ann) (RawExp ann)
  | -- | See Note [IR primops]
    PrimBinOp ann PrimOp (RawExp ann) (RawExp ann)
  | -- | See Note [IR primops]
    PrimNot ann (RawExp ann)
  | DataArgumentByIndex ann AlgebraicType Natural (RawExp ann)
  | ArrayLength ann (RawExp ann)
  | ArrayIndex ann (RawExp ann) Natural
  | ObjectProp ann (RawExp ann) PropName
  | ObjectUpdate ann (RawExp ann) (NonEmpty (PropName, RawExp ann))
  | AbsN ann (NonEmpty (Parameter ann)) (RawExp ann)
  | AppN ann (RawExp ann) (NonEmpty (RawExp ann))
  | Ref ann (Qualified Name)
  | Let ann (NonEmpty (Grouping (ann, Name, RawExp ann))) (RawExp ann)
  | IfThenElse ann (RawExp ann) (RawExp ann) (RawExp ann)
  | Exception ann Text
  | ForeignImport ann ModuleName FilePath [(ann, Name)]

{- Note [n-ary application]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'AppN f (a₁ :| [a₂, …, aₙ])' is a single Lua call @f(a₁, a₂, …, aₙ)@. The
argument list is not a flattened application spine: 'AppN f [a, b]' (one
call, @f(a, b)@) and 'AppN (AppN f [a]) [b]' (two calls, @f(a)(b)@) denote
different programs, because Lua silently drops surplus arguments and fills
missing ones with nil. Currying therefore stays expressed by nesting,
exactly as CoreFn produces it.

Translation and every existing rewrite rule build and match the unary
singleton through the 'App' pattern synonym below, so they are oblivious
to genuinely n-ary calls. A multi-argument node is introduced only by a
pass that can prove the callee consumes every argument in one call:
today the uncurrying worker/wrapper split
("Language.PureScript.Backend.IR.Uncurry"), and eventually the lifting
of the uncurried @*.Uncurried@ wrappers to direct calls. The linter's
'Language.PureScript.Backend.IR.Linter.lintWellApplied' invariant rejects
the ill-formed shapes such a pass must never emit: a literal lambda
applied to a number of arguments different from the number of parameters
it binds.
-}

{- | The unary application @f a@ — the singleton 'AppN'. As a constructor
it builds the one-argument call; as a pattern it matches exactly the
one-argument calls, leaving genuinely n-ary nodes to fall through to a
later alternative. Every unary rule keeps using it unchanged.
-}
pattern App ∷ ann → RawExp ann → RawExp ann → RawExp ann
pattern App ann f a = AppN ann f (a :| [])

{- | Peel a curried unary-'App' spine into its head and its arguments,
first-applied first: @App (App f a₁) a₂@ becomes @(f, [a₁, a₂])@. A
genuinely n-ary 'AppN' node is not a spine link and stays in the head
(see Note [n-ary application]).
-}
unwindApp ∷ ∀ ann. RawExp ann → (RawExp ann, [RawExp ann])
unwindApp = go []
 where
  go ∷ [RawExp ann] → RawExp ann → (RawExp ann, [RawExp ann])
  go acc = \case
    App _ f a → go (a : acc) f
    e → (e, acc)

{- Note [n-ary abstraction]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The definition-side counterpart of Note [n-ary application].
'AbsN (p₁ :| [p₂, …, pₙ]) body' is a single Lua function
@function(p₁, p₂, …, pₙ)@. The parameter list is not a flattened lambda
chain: 'AbsN [p, q] b' (one function of two parameters, both bound at
one call) and 'AbsN [p] (AbsN [q] b)' (a function returning a closure)
denote different programs, for the same reason as on the application
side: Lua fills missing arguments with nil instead of currying.
Currying therefore stays expressed by nesting, exactly as CoreFn
produces it.

Translation and every existing rewrite rule build and match the unary
singleton through the 'Abs' pattern synonym below. A multi-parameter
node is introduced only by a pass that guarantees every application of
it is saturated (the worker half of the uncurrying worker/wrapper
split). Two well-formedness conditions accompany the node, both checked
by 'Language.PureScript.Backend.IR.Linter.lintWellApplied':

  * a literal 'AbsN' head is applied to exactly as many arguments as it
    binds parameters (see Note [n-ary application]);

  * 'ParamUnused' occurs only as a trailing run of the parameter list.
    The Lua backend must drop unused parameters (see
    Note [Nullary functions and Prim.undefined] in
    "Language.PureScript.Backend.Lua"), and dropping a non-trailing one
    would shift every parameter after it. Producers uphold this by
    construction; dead-code elimination blanks only a dead /suffix/ of
    an 'AbsN' parameter list.
-}

{- | The unary abstraction @λp. body@ — the singleton 'AbsN'. As a
constructor it builds the one-parameter function; as a pattern it
matches exactly the one-parameter functions, leaving genuinely n-ary
nodes to fall through to a later alternative. Every unary rule keeps
using it unchanged.
-}
pattern Abs ∷ ann → Parameter ann → RawExp ann → RawExp ann
pattern Abs ann param body = AbsN ann (param :| []) body

{- Note [Sequential scoping of Let bindings]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A local variable is referenced by name ('Ref _ (Local name)') and
resolves to the innermost enclosing binder of that name. Which binders
of a 'Let' are in scope where? The convention is sequential, like
Scheme's let*:

  * the RHS of a Standalone binding sees the *earlier* siblings of the
    same Let; the binding's own name is NOT in scope there, so a
    reference to it from its own RHS points at an outer binder
    (Standalone bindings are non-recursive);

  * the RHS of a RecursiveGroup member sees the earlier groupings of
    the same Let and every member of its own group, itself included;

  * the body sees all the bindings.

For example:

  let a = ...       -- sees only the enclosing scope
      b = f a       -- a is the sibling directly above
      a = g a b     -- a is the FIRST binding, not itself
  in h a b          -- a is the SECOND binding: it shadows the first

Shadowing makes resolution position-dependent, so every traversal that
walks under Let binders while duplicate names can still occur — i.e.
anything at or upstream of
'Language.PureScript.Backend.IR.Uniquify.uniquifyNames', the pipeline's
entry pass — must implement this convention, and they must all agree:

  * 'countFreeRefs' threads the scope through the groupings left to right;

  * 'alphaEq' resolves names to binder positions the same way, so it
    stays correct on shadowed input;

  * the well-scopedness lint
    ('Language.PureScript.Backend.IR.Linter.unboundLocals' — the
    requires-contract of 'uniquifyNames' itself, so it must accept
    shadowed shapes) tracks bound names the same way;

  * 'qualifyTopRefs' (Linker, ahead of the optimizer pipeline) decides
    whether a local reference escapes to a top-level binding by
    threading bound names the same way;

  * 'Language.PureScript.Backend.IR.Uniquify.uniquifyNamesInExpr'
    resolves names to fresh, site-wide unique names the same way,
    establishing the global-uniqueness condition (GUC =
    @UniqueBinders@, issue #139) that every later pass requires and
    preserves.

Once GUC holds, at most one binder of any name is in scope, so the
convention above can no longer produce an ambiguous resolution — but
'uniquifyNames' itself, and everything upstream of it, must still get
it right. The Lua code generator emits Standalone bindings of a Let as
a sequence of 'local' statements, which is exactly let* scoping on the
Lua side (the Let case of 'fromIR').

Getting one of the walkers wrong miscompiles: in issue #37 an optimizer
traversal resolved a sibling-bound reference against the wrong binder,
DCE then deleted the "unused" binder, and codegen rendered the dangling
reference as an undefined Lua variable. The golden test
test/ps/src/Golden/Issue37/Test.purs and the "Let sequential (let*)
scoping" tests pin the convention.
-}

deriving stock instance Show ann ⇒ Show (RawExp ann)
deriving stock instance Eq ann ⇒ Eq (RawExp ann)
deriving stock instance Ord ann ⇒ Ord (RawExp ann)

{- | Map/fold/traverse over every annotation of the expression: the
per-node @ann@s, the 'Parameter' annotations, the name annotations of
'Let' bindings, and the name annotations of a 'ForeignImport'.
-}
deriving stock instance Functor RawExp

deriving stock instance Foldable RawExp
deriving stock instance Traversable RawExp

getAnn ∷ RawExp ann → ann
getAnn = \case
  LiteralInt ann _ → ann
  LiteralFloat ann _ → ann
  LiteralString ann _ → ann
  LiteralChar ann _ → ann
  LiteralBool ann _ → ann
  LiteralArray ann _ → ann
  LiteralObject ann _ → ann
  Ctor ann _ _ _ _ _ → ann
  ReflectCtor ann _ → ann
  Eq ann _ _ → ann
  PrimBinOp ann _ _ _ → ann
  PrimNot ann _ → ann
  DataArgumentByIndex ann _ _ _ → ann
  ArrayLength ann _ → ann
  ArrayIndex ann _ _ → ann
  ObjectProp ann _ _ → ann
  ObjectUpdate ann _ _ → ann
  AbsN ann _ _ → ann
  AppN ann _ _ → ann
  Ref ann _ → ann
  Let ann _ _ → ann
  IfThenElse ann _ _ _ → ann
  Exception ann _ → ann
  ForeignImport ann _ _ _ → ann

{- | Replace the root annotation, leaving every other node's annotation
(children, 'Parameter's, 'Let' binder names, 'ForeignImport' names)
untouched. The symmetric setter to 'getAnn'.
-}
setAnn ∷ ann → RawExp ann → RawExp ann
setAnn ann = \case
  LiteralInt _ n → LiteralInt ann n
  LiteralFloat _ n → LiteralFloat ann n
  LiteralString _ s → LiteralString ann s
  LiteralChar _ c → LiteralChar ann c
  LiteralBool _ b → LiteralBool ann b
  LiteralArray _ es → LiteralArray ann es
  LiteralObject _ props → LiteralObject ann props
  Ctor _ algTy modName tyName ctorName fields →
    Ctor ann algTy modName tyName ctorName fields
  ReflectCtor _ e → ReflectCtor ann e
  Eq _ l r → Eq ann l r
  PrimBinOp _ op l r → PrimBinOp ann op l r
  PrimNot _ e → PrimNot ann e
  DataArgumentByIndex _ algTy i e → DataArgumentByIndex ann algTy i e
  ArrayLength _ e → ArrayLength ann e
  ArrayIndex _ e i → ArrayIndex ann e i
  ObjectProp _ e prop → ObjectProp ann e prop
  ObjectUpdate _ e patches → ObjectUpdate ann e patches
  AbsN _ params body → AbsN ann params body
  AppN _ f args → AppN ann f args
  Ref _ qname → Ref ann qname
  Let _ binds body → Let ann binds body
  IfThenElse _ cond th el → IfThenElse ann cond th el
  Exception _ msg → Exception ann msg
  ForeignImport _ modName path names → ForeignImport ann modName path names

isLiteral ∷ RawExp ann → Bool
isLiteral = (||) <$> isNonRecursiveLiteral <*> isRecursiveLiteral

isNonRecursiveLiteral ∷ RawExp ann → Bool
isNonRecursiveLiteral = \case
  LiteralInt {} → True
  LiteralFloat {} → True
  LiteralString {} → True
  LiteralChar {} → True
  LiteralBool {} → True
  _ → False

isRecursiveLiteral ∷ RawExp ann → Bool
isRecursiveLiteral = \case
  LiteralArray {} → True
  LiteralObject {} → True
  _ → False

isForeignImport ∷ RawExp ann → Bool
isForeignImport = \case
  ForeignImport {} → True
  _ → False

{- | The synthetic argument magic-do applies a thunk to in order to /run/ it.

A dedicated marker, distinct from the @Prim.undefined@ argument PureScript emits
to force an ordinary nullary thunk (Note [Nullary functions and Prim.undefined]
in 'Language.PureScript.Backend.Lua'). Both are ignored by the receiving
'ParamUnused' and both are erased to an empty argument list by the Lua backend —
but only this one marks an /effect run/. Giving magic-do its own token lets
'isEffectRun' recognise exactly the effect runs magic-do introduces and not the
coincidentally nullary thunks that share the @f Prim.undefined@ shape: a
superclass-dictionary accessor or a newtype coercion (@runIdentity@) inlined off
a non-Effect monad (@State@\/@Writer@). Conflating the two kept beta reduction
from collapsing those pure thunks, bloating the output (issue #180). The @$@ in
the name cannot collide with a PureScript identifier.
-}
pattern EffectRunArg ∷ ann → RawExp ann
pattern EffectRunArg ann =
  Ref ann (Imported (ModuleName "Prim") (Name "$magicDoRun"))

{- | Recognise an Effect/ST statement as magic-do emits it: running a thunk, the
application @m EffectRunArg@ (see 'Language.PureScript.Backend.IR.MagicDo'). Its
side effect is observable and its statement sequencing is size-managed by
magic-do's chunking, so passes that run after magic-do must leave it alone:
dead-code elimination keeps it even when its binder is unreferenced, beta
reduction does not reduce through it (which would merge a chunk into its parent
and overflow Lua's local-variable limit), and local inlining does not paste a
run bound by a Let statement into the body (the kept statement plus the pasted
copy would execute the effect twice).
-}
isEffectRun ∷ RawExp ann → Bool
isEffectRun = \case
  AppN _ _ (EffectRunArg _ :| []) → True
  _ → False

ctorId ∷ ModuleName → TyName → CtorName → Text
ctorId modName tyName ctorName =
  runModuleName modName
    <> "∷"
    <> renderTyName tyName
    <> "."
    <> renderCtorName ctorName

--------------------------------------------------------------------------------
-- Instances -------------------------------------------------------------------

$(deriveEq1 ''Grouping)
$(deriveOrd1 ''Grouping)

deriving stock instance Show Module

deriving stock instance Eq Module

instance Ord Module where
  compare a b = compare (moduleName a) (moduleName b)

-- Constructors for expresssions -----------------------------------------------

arrayIndex ∷ Exp → Natural → Exp
arrayIndex = ArrayIndex noAnn

objectProp ∷ Exp → PropName → Exp
objectProp = ObjectProp noAnn

objectUpdate ∷ Exp → NonEmpty (PropName, Exp) → Exp
objectUpdate = ObjectUpdate noAnn

ctor ∷ AlgebraicType → ModuleName → TyName → CtorName → [FieldName] → Exp
ctor = Ctor noAnn

abstraction ∷ Parameter Ann → Exp → Exp
abstraction = Abs noAnn

abstractionN ∷ NonEmpty (Parameter Ann) → Exp → Exp
abstractionN = AbsN noAnn

identity ∷ Exp
identity =
  let name = Name "x"
   in abstraction (paramNamed name) (refLocal name)

lets ∷ NonEmpty Binding → Exp → Exp
lets = Let noAnn

application ∷ Exp → Exp → Exp
application = App noAnn

applicationN ∷ Exp → NonEmpty Exp → Exp
applicationN = AppN noAnn

paramNamed ∷ Name → Parameter Ann
paramNamed = ParamNamed noAnn

paramUnused ∷ Parameter Ann
paramUnused = ParamUnused noAnn

ref ∷ Qualified Name → Exp
ref = Ref noAnn

refLocal ∷ Name → Exp
refLocal = Ref noAnn . Local

refImported ∷ ModuleName → Name → Exp
refImported modname name = Ref noAnn (Imported modname name)

ifThenElse ∷ Exp → Exp → Exp → Exp
ifThenElse = IfThenElse noAnn

exception ∷ Text → Exp
exception = Exception noAnn

--------------------------------------------------------------------------------
-- Constructors for primitive operations ---------------------------------------

eq ∷ Exp → Exp → Exp
eq = Eq noAnn

primBinOp ∷ PrimOp → Exp → Exp → Exp
primBinOp = PrimBinOp noAnn

primNot ∷ Exp → Exp
primNot = PrimNot noAnn

arrayLength ∷ Exp → Exp
arrayLength = ArrayLength noAnn

reflectCtor ∷ Exp → Exp
reflectCtor = ReflectCtor noAnn

dataArgumentByIndex ∷ AlgebraicType → Natural → Exp → Exp
dataArgumentByIndex = DataArgumentByIndex noAnn

--------------------------------------------------------------------------------
-- Constructors for literals ---------------------------------------------------

literalBool ∷ Bool → Exp
literalBool = LiteralBool noAnn

literalInt ∷ Integer → Exp
literalInt = LiteralInt noAnn

asLiteralInt ∷ Prism' Exp Integer
asLiteralInt = prism' literalInt \case
  LiteralInt _ann i → Just i
  _ → Nothing

literalFloat ∷ Double → Exp
literalFloat = LiteralFloat noAnn

asLiteralFloat ∷ Prism' Exp Double
asLiteralFloat = prism' literalFloat \case
  LiteralFloat _ann f → Just f
  _ → Nothing

literalString ∷ Text → Exp
literalString = LiteralString noAnn

asLiteralString ∷ Prism' Exp Text
asLiteralString = prism' literalString \case
  LiteralString _ann s → Just s
  _ → Nothing

literalChar ∷ Char → Exp
literalChar = LiteralChar noAnn

asLiteralChar ∷ Prism' Exp Char
asLiteralChar = prism' literalChar \case
  LiteralChar _ann c → Just c
  _ → Nothing

literalArray ∷ [Exp] → Exp
literalArray = LiteralArray noAnn

literalObject ∷ [(PropName, Exp)] → Exp
literalObject = LiteralObject noAnn

--------------------------------------------------------------------------------
-- Traversals ------------------------------------------------------------------

{-# INLINE subexpressions #-}

-- | Get all the direct child 'RawExp's of the given 'RawExp'
subexpressions ∷ Traversal' (RawExp ann) (RawExp ann)
subexpressions go = \case
  LiteralArray ann as →
    LiteralArray ann <$> traverse go as
  LiteralObject ann props →
    LiteralObject ann <$> traverse (traverse go) props
  ReflectCtor ann a →
    ReflectCtor ann <$> go a
  DataArgumentByIndex ann algTy idx a →
    DataArgumentByIndex ann algTy idx <$> go a
  Eq ann a b →
    Eq ann <$> go a <*> go b
  PrimBinOp ann op a b →
    PrimBinOp ann op <$> go a <*> go b
  PrimNot ann a →
    PrimNot ann <$> go a
  ArrayLength ann a →
    ArrayLength ann <$> go a
  ArrayIndex ann a idx →
    ArrayIndex ann <$> go a <*> pure idx
  ObjectProp ann a prp →
    ObjectProp ann <$> go a <*> pure prp
  ObjectUpdate ann a ps →
    ObjectUpdate ann <$> go a <*> traverse (traverse go) ps
  AppN ann f args →
    AppN ann <$> go f <*> traverse go args
  AbsN ann params a →
    AbsN ann params <$> go a
  Let ann bs body →
    Let ann
      <$> traverse (traverse (\(a, n, expr) → (a,n,) <$> go expr)) bs
      <*> go body
  IfThenElse ann p th el →
    IfThenElse ann <$> go p <*> go th <*> go el
  e → pure e

{- | A rewrite rule: 'Nothing' when the rule does not apply to the node,
'Just' the rewritten node when it fired.

The contract: a rule must return 'Just' only when it actually changed
something. The drivers below surface "did any rule fire" as the
'WasRewritten' signal the optimizer fixpoint trusts: a rule that
reports 'Just' with an unchanged result spins the fixpoint until its
iteration cap, and one that changes something under 'Nothing' stops it
early — both are caught loudly by the checked pipeline runner
("Language.PureScript.Backend.IR.Pass").
-}
type RewriteRule ann = RawExp ann → Maybe (RawExp ann)

-- | Effectful 'RewriteRule'.
type RewriteRuleM m ann = RawExp ann → m (Maybe (RawExp ann))

{- | Did rewriting change anything? The '(<>)' answers "did either":
'Rewritten' wins, 'Unmodified' is 'mempty'. 'Unmodified' asserts the
result is structurally identical to the input; 'Rewritten' says it may
differ.
-}
data WasRewritten = Rewritten | Unmodified
  deriving stock (Show, Eq)

instance Semigroup WasRewritten where
  Unmodified <> Unmodified = Unmodified
  _ <> _ = Rewritten

instance Monoid WasRewritten where
  mempty = Unmodified

-- | 'Rewritten' iff the condition holds.
rewrittenIf ∷ Bool → WasRewritten
rewrittenIf b = if b then Rewritten else Unmodified

{- | Sequential composition: apply the second rule to the first rule's
result (or to the original expression when the first did not fire).
The composite fires iff either rule fired.
-}
thenRewrite
  ∷ Monad m
  ⇒ RewriteRuleM m ann
  → RewriteRuleM m ann
  → RewriteRuleM m ann
thenRewrite rewrite1 rewrite2 e =
  rewrite1 e >>= \case
    Just e' → Just . fromMaybe e' <$> rewrite2 e'
    Nothing → rewrite2 e

{- | Rewrite bottom-up: every node's children are fully rewritten before
the rule sees the node, and the rule is re-applied to its own result
until it no longer fires ('rewriteMOf' semantics). One pass is
therefore complete and idempotent — the result contains no node the
rule still fires on — which is what makes the returned 'WasRewritten'
precise, and what closes the Recurse-escape bug class (issue #149)
structurally: a node exposed by a collapsing parent has already been
fully rewritten.
-}
rewriteExpBottomUpM
  ∷ Monad m ⇒ RewriteRuleM m ann → RawExp ann → m (RawExp ann, WasRewritten)
rewriteExpBottomUpM rule expr =
  runWriterT $ flip (rewriteMOf subexpressions) expr \e →
    lift (rule e) >>= traverse \e' → e' <$ tell Rewritten

-- | Pure 'rewriteExpBottomUpM'.
rewriteExpBottomUp ∷ RewriteRule ann → RawExp ann → (RawExp ann, WasRewritten)
rewriteExpBottomUp rule = runIdentity . rewriteExpBottomUpM (pure . rule)

{- | Rewrite top-down: re-apply the rule at the node until it no longer
fires, then descend into the children of the result.

Reserved for the order-sensitive lowerings that consume a pattern
spanning a node and its descendants from the outside in — magic-do
chains ("Language.PureScript.Backend.IR.MagicDo") and deep-bind
flattening ("Language.PureScript.Backend.IR.FlattenDeepBinds"). A
bottom-up driver would dismantle such a chain from the inside out
(every tail of a magic-do chain is itself a chain head), rewriting it
into per-step nested thunks and defeating the flattening that is the
point of those passes. Termination is the rule's obligation: it must
not fire on the root of its own result.
-}
rewriteExpTopDownM ∷ Monad m ⇒ RewriteRuleM m ann → RawExp ann → m (RawExp ann)
rewriteExpTopDownM rule = visit
 where
  visit expression =
    rule expression >>= \case
      Just expression' → visit expression'
      Nothing → traverseOf subexpressions visit expression

countFreeRefs ∷ RawExp ann → Map (Qualified Name) Natural
countFreeRefs = fmap getSum . MMap.toMap . countFreeRefs' mempty
 where
  countFreeRefs'
    ∷ Set Name
    → RawExp ann
    → MonoidMap (Qualified Name) (Sum Natural)
  countFreeRefs' bound = \case
    Ref _ann qname →
      case qname of
        Local name
          | Set.member name bound → mempty
        _ → MMap.singleton qname (Sum 1)
    AbsN _ann params body →
      countFreeRefs' (foldl' bindParam bound params) body
     where
      bindParam ∷ Set Name → Parameter ann → Set Name
      bindParam names = \case
        ParamNamed _paramAnn name → Set.insert name names
        ParamUnused _paramAnn → names
    -- See Note [Sequential scoping of Let bindings]
    Let _ann binds body → fold (countsInBody : countsInBinds)
     where
      countsInBody = countFreeRefs' boundAfterBinds body
      (boundAfterBinds, countsInBinds) =
        foldl' withGrouping (bound, []) (toList binds)
      withGrouping
        ∷ (Set Name, [MonoidMap (Qualified Name) (Sum Natural)])
        → Grouping (ann, Name, RawExp ann)
        → (Set Name, [MonoidMap (Qualified Name) (Sum Natural)])
      withGrouping (names, counts) = \case
        Standalone (_nameAnn, boundName, expr) →
          ( Set.insert boundName names
          , countFreeRefs' names expr : counts
          )
        RecursiveGroup recBinds →
          ( namesAfterGroup
          , ( toList recBinds <&> \(_nameAnn, _boundName, expr) →
                countFreeRefs' namesAfterGroup expr
            )
              <> counts
          )
         where
          namesAfterGroup =
            foldr
              (\(_nameAnn, boundName, _expr) → Set.insert boundName)
              names
              recBinds
    -- No other constructor binds names, so the scope passes through:
    other → foldMapOf subexpressions (countFreeRefs' bound) other

countFreeRef ∷ Qualified Name → RawExp ann → Natural
countFreeRef name = Map.findWithDefault 0 name . countFreeRefs

{- | Where a reference sits relative to the expression root: reached
unconditionally, only inside an 'IfThenElse' arm, or from inside a
nested 'AbsN'. Ordered by escalation; combines by taking the strongest
context.
-}
data Capture = CaptureNone | CaptureBranch | CaptureClosure
  deriving stock (Show, Eq, Ord)

instance Semigroup Capture where
  (<>) = max

instance Monoid Capture where
  mempty = CaptureNone

{- | Aggregate of one name's free references: how many, and the
strongest 'Capture' context any of them sits under.
-}
data Usage = Usage {usageTotal ∷ Natural, usageCapture ∷ Capture}
  deriving stock (Show, Eq)

instance Semigroup Usage where
  Usage t1 c1 <> Usage t2 c2 = Usage (t1 + t2) (c1 <> c2)

instance Monoid Usage where
  mempty = Usage 0 mempty

{- | 'countFreeRef' enriched with the 'Capture' context of the counted
references: the traversal threads the strongest wrapper crossed between
the expression root and each reference site — an 'AbsN' body raises the
context to 'CaptureClosure', an 'IfThenElse' arm (not the condition) to
'CaptureBranch'. A 'Let' defers nothing: its RHSs and body evaluate
when the 'Let' does, so the context passes through unchanged and only
the bound-name set advances (Note [Sequential scoping of Let bindings]).
-}
countFreeRefUsage ∷ Qualified Name → RawExp ann → Usage
countFreeRefUsage name = go CaptureNone mempty
 where
  go ∷ Capture → Set Name → RawExp ann → Usage
  go cap bound = \case
    Ref _ann qname
      | qname == name → case qname of
          Local n | Set.member n bound → mempty
          _ → Usage 1 cap
      | otherwise → mempty
    AbsN _ann params body →
      go (cap <> CaptureClosure) (foldl' bindParam bound params) body
     where
      bindParam ∷ Set Name → Parameter ann → Set Name
      bindParam names = \case
        ParamNamed _paramAnn n → Set.insert n names
        ParamUnused _paramAnn → names
    IfThenElse _ann cond thenBranch elseBranch →
      go cap bound cond
        <> go (cap <> CaptureBranch) bound thenBranch
        <> go (cap <> CaptureBranch) bound elseBranch
    -- See Note [Sequential scoping of Let bindings]
    Let _ann binds body → fold (usageInBody : usagesInBinds)
     where
      usageInBody = go cap boundAfterBinds body
      (boundAfterBinds, usagesInBinds) =
        foldl' withGrouping (bound, []) (toList binds)
      withGrouping
        ∷ (Set Name, [Usage])
        → Grouping (ann, Name, RawExp ann)
        → (Set Name, [Usage])
      withGrouping (names, usages) = \case
        Standalone (_nameAnn, boundName, expr) →
          (Set.insert boundName names, go cap names expr : usages)
        RecursiveGroup recBinds →
          ( namesAfterGroup
          , ( toList recBinds <&> \(_nameAnn, _boundName, expr) →
                go cap namesAfterGroup expr
            )
              <> usages
          )
         where
          namesAfterGroup =
            foldr
              (\(_nameAnn, boundName, _expr) → Set.insert boundName)
              names
              recBinds
    -- No other constructor binds names or defers/conditions evaluation,
    -- so both context components pass through:
    other → foldMapOf subexpressions (go cap bound) other

{- | Structural equality modulo the names of locally-bound binders.

Two expressions are alpha-equivalent when they differ at most in the
names chosen for the binders they introduce ('Abs' parameters and 'Let'
bindings). Local references are compared by the binder they resolve to,
not by name: bound references must resolve to corresponding binder
positions (binders are numbered in lockstep on both sides), while free
references must agree on the name, because both sides live in the same
enclosing scope. Resolution — to the innermost enclosing binder of the
name — follows Note [Sequential scoping of Let bindings].

Everything else — annotations, imported references, foreign import
name lists — is compared exactly as the derived 'Eq' would, so
'alphaEq' is strictly weaker than '(==)'.
-}
alphaEq ∷ Eq ann ⇒ RawExp ann → RawExp ann → Bool
alphaEq = go 0 Map.empty Map.empty
 where
  go
    ∷ Eq ann
    ⇒ Natural
    → Map Name Natural
    → Map Name Natural
    → RawExp ann
    → RawExp ann
    → Bool
  go lvl scopeL scopeR exprL exprR = case (exprL, exprR) of
    (Ref annL (Local nameL), Ref annR (Local nameR)) →
      annL == annR
        && case (Map.lookup nameL scopeL, Map.lookup nameR scopeR) of
          (Just levelL, Just levelR) → levelL == levelR
          (Nothing, Nothing) → nameL == nameR
          _ → False
    (AbsN annL paramsL bodyL, AbsN annR paramsR bodyR) →
      annL == annR
        && goAbs
          lvl
          scopeL
          scopeR
          (toList paramsL)
          (toList paramsR)
          bodyL
          bodyR
    (Let annL bindsL bodyL, Let annR bindsR bodyR) →
      annL == annR
        && goLet lvl scopeL scopeR (toList bindsL) (toList bindsR) bodyL bodyR
    (AppN annL fL argsL, AppN annR fR argsR) →
      annL == annR
        && length argsL == length argsR
        && go lvl scopeL scopeR fL fR
        && and (zipWith (go lvl scopeL scopeR) (toList argsL) (toList argsR))
    (LiteralArray annL asL, LiteralArray annR asR) →
      annL == annR
        && length asL == length asR
        && and (zipWith (go lvl scopeL scopeR) asL asR)
    (LiteralObject annL propsL, LiteralObject annR propsR) →
      annL == annR && goProps lvl scopeL scopeR propsL propsR
    (ObjectUpdate annL aL patchesL, ObjectUpdate annR aR patchesR) →
      annL == annR
        && go lvl scopeL scopeR aL aR
        && goProps lvl scopeL scopeR (toList patchesL) (toList patchesR)
    (ReflectCtor annL aL, ReflectCtor annR aR) →
      annL == annR && go lvl scopeL scopeR aL aR
    (Eq annL aL bL, Eq annR aR bR) →
      annL == annR && go lvl scopeL scopeR aL aR && go lvl scopeL scopeR bL bR
    (PrimBinOp annL opL aL bL, PrimBinOp annR opR aR bR) →
      annL == annR
        && opL == opR
        && go lvl scopeL scopeR aL aR
        && go lvl scopeL scopeR bL bR
    (PrimNot annL aL, PrimNot annR aR) →
      annL == annR && go lvl scopeL scopeR aL aR
    (DataArgumentByIndex annL tL iL aL, DataArgumentByIndex annR tR iR aR) →
      annL == annR && tL == tR && iL == iR && go lvl scopeL scopeR aL aR
    (ArrayLength annL aL, ArrayLength annR aR) →
      annL == annR && go lvl scopeL scopeR aL aR
    (ArrayIndex annL aL iL, ArrayIndex annR aR iR) →
      annL == annR && iL == iR && go lvl scopeL scopeR aL aR
    (ObjectProp annL aL pL, ObjectProp annR aR pR) →
      annL == annR && pL == pR && go lvl scopeL scopeR aL aR
    (IfThenElse annL pL tL eL, IfThenElse annR pR tR eR) →
      annL == annR
        && go lvl scopeL scopeR pL pR
        && go lvl scopeL scopeR tL tR
        && go lvl scopeL scopeR eL eR
    -- Imported/mismatched-qualifier refs, terminals and pairs of
    -- different constructors:
    _ → exprL == exprR

  -- Parameters are compared positionally, binding levels in lockstep;
  -- a length mismatch falls through to False.
  goAbs
    ∷ Eq ann
    ⇒ Natural
    → Map Name Natural
    → Map Name Natural
    → [Parameter ann]
    → [Parameter ann]
    → RawExp ann
    → RawExp ann
    → Bool
  goAbs lvl scopeL scopeR paramsL paramsR bodyL bodyR =
    case (paramsL, paramsR) of
      ([], []) → go lvl scopeL scopeR bodyL bodyR
      (ParamUnused paL : psL, ParamUnused paR : psR) →
        paL == paR && goAbs lvl scopeL scopeR psL psR bodyL bodyR
      (ParamNamed paL nameL : psL, ParamNamed paR nameR : psR) →
        paL == paR
          && goAbs
            (lvl + 1)
            (bindLevel nameL lvl scopeL)
            (bindLevel nameR lvl scopeR)
            psL
            psR
            bodyL
            bodyR
      _ → False

  goLet
    ∷ Eq ann
    ⇒ Natural
    → Map Name Natural
    → Map Name Natural
    → [Grouping (ann, Name, RawExp ann)]
    → [Grouping (ann, Name, RawExp ann)]
    → RawExp ann
    → RawExp ann
    → Bool
  goLet lvl scopeL scopeR groupingsL groupingsR bodyL bodyR =
    case (groupingsL, groupingsR) of
      ([], []) → go lvl scopeL scopeR bodyL bodyR
      (Standalone (aL, nL, eL) : gsL, Standalone (aR, nR, eR) : gsR) →
        aL == aR
          -- The RHS of a Standalone binding does not see its own binder:
          && go lvl scopeL scopeR eL eR
          && goLet
            (lvl + 1)
            (bindLevel nL lvl scopeL)
            (bindLevel nR lvl scopeR)
            gsL
            gsR
            bodyL
            bodyR
      (RecursiveGroup recL : gsL, RecursiveGroup recR : gsR) →
        let membersL = toList recL
            membersR = toList recR
            bindMembers members scope =
              foldl'
                (\sc ((_a, n, _e), l) → bindLevel n l sc)
                scope
                (zip members [lvl ..])
            scopeL' = bindMembers membersL scopeL
            scopeR' = bindMembers membersR scopeR
            lvl' = lvl + fromIntegral (length membersL)
         in length membersL == length membersR
              && and
                ( zipWith
                    ( \(aL, _nL, eL) (aR, _nR, eR) →
                        aL == aR && go lvl' scopeL' scopeR' eL eR
                    )
                    membersL
                    membersR
                )
              && goLet lvl' scopeL' scopeR' gsL gsR bodyL bodyR
      _ → False

  goProps
    ∷ Eq ann
    ⇒ Natural
    → Map Name Natural
    → Map Name Natural
    → [(PropName, RawExp ann)]
    → [(PropName, RawExp ann)]
    → Bool
  goProps lvl scopeL scopeR propsL propsR =
    length propsL == length propsR
      && and
        ( zipWith
            (\(pL, eL) (pR, eR) → pL == pR && go lvl scopeL scopeR eL eR)
            propsL
            propsR
        )

  -- The innermost binder of a name shadows any outer one.
  bindLevel ∷ Name → Natural → Map Name Natural → Map Name Natural
  bindLevel = Map.insert

{- | Rename every binder bound /within/ the expression to a fresh
supply-minted name (@\<original\>$\<n\>@ — the @$@ cannot occur in a
source identifier, so a mint can never collide with one), rewriting the
references each binder binds. Free references — bound outside the
expression — are untouched.

Correct only under the GUC discipline (@UniqueBinders@): binders
within the expression are unique, so a reference belongs to a binder
iff the names match, and the sequential scoping subtleties of
Note [Sequential scoping of Let bindings] cannot be observed.
'ParamUnused' binds nothing, and the name list of a 'ForeignImport'
holds the export keys of the foreign source file, not binders —
neither is renamed.
-}
freshenBinders ∷ ∀ ann. RawExp ann → SupplyM (RawExp ann)
freshenBinders = go Map.empty
 where
  go ∷ Map Name Name → RawExp ann → SupplyM (RawExp ann)
  go renames = \case
    r@(Ref ann qname)
      | Local name ← qname
      , Just renamed ← Map.lookup name renames →
          pure (Ref ann (Local renamed))
      | otherwise → pure r
    AbsN ann params body → do
      (renames', params') ← mapAccumM freshenParam renames params
      AbsN ann params' <$> go renames' body
     where
      freshenParam
        ∷ Map Name Name
        → Parameter ann
        → SupplyM (Map Name Name, Parameter ann)
      freshenParam rs = \case
        p@(ParamUnused _paramAnn) → pure (rs, p)
        ParamNamed paramAnn name → do
          name' ← freshNameFor name
          pure (Map.insert name name' rs, ParamNamed paramAnn name')
    Let ann binds body → do
      -- Under unique binders no Let name can be referenced before it is
      -- bound, so all the groupings can enter the rename map up front.
      -- The discard binder `_` stays out of the map: it is exempt from
      -- the uniqueness invariant, so one Let can bind it several times
      -- (magic-do's discard statements), and a single name-keyed entry
      -- would rename every one of them to the same fresh name — a
      -- genuine duplicate the exemption no longer covers. Nothing may
      -- reference it, so it needs no rename at all.
      renames' ←
        foldlM
          ( \rs name → do
              name' ← freshNameFor name
              pure (Map.insert name name' rs)
          )
          renames
          (filter (/= discardName) (bindingNames =<< toList binds))
      let renameBound (bindAnn, name, expr) =
            (bindAnn,Map.findWithDefault name name renames',)
              <$> go renames' expr
      Let ann <$> traverse (traverse renameBound) binds <*> go renames' body
    -- No other constructor binds or references names ('ForeignImport'
    -- included: its name list holds export keys, not binders):
    other → traverseOf subexpressions (go renames) other

  freshNameFor ∷ Name → SupplyM Name
  freshNameFor name = freshName (nameToText name <> "$")

{- | Substitution under the GUC discipline: replace every occurrence of
the variable with the replacement. There is no scope threading: under
unique binders the substituted name cannot be rebound inside the
target, and the replacement's free references cannot be captured at any
insertion point. Matched occurrences are replaced, never descended
into, so a replacement referring to the substituted name itself is
safe.

Both variants keep 'UniqueBinders' intact when the replacement contains
binders; they differ in what they assume about the /source/ of the
replacement:

  * 'substituteCopyM' — the source binding survives the rewrite (e.g. a
    Let binding inlined into its body and removed only later, by DCE),
    so every inserted copy is freshened with 'freshenBinders';

  * 'substituteMoveM' — the source binder is consumed by the same
    rewrite (e.g. the λ of a beta redex), so the first occurrence
    receives the replacement verbatim and only further occurrences are
    freshened.

Zero matching occurrences ⇒ the target is returned unchanged and no
supply names are drawn (freshening is per-occurrence, never eager):
the optimize fixpoint relies on this to converge, and golden name
numbering relies on it for stability.
-}
substituteCopyM
  ∷ Qualified Name → RawExp ann → RawExp ann → SupplyM (RawExp ann)
substituteCopyM = substituteFreshening True

-- | See 'substituteCopyM'.
substituteMoveM
  ∷ Qualified Name → RawExp ann → RawExp ann → SupplyM (RawExp ann)
substituteMoveM = substituteFreshening False

substituteFreshening
  ∷ ∀ ann
   . Bool
  -- ^ Whether to freshen the first inserted occurrence too
  → Qualified Name
  → RawExp ann
  → RawExp ann
  → SupplyM (RawExp ann)
substituteFreshening freshenFirst name replacement target =
  evalStateT (go target) freshenFirst
 where
  -- The state is whether the next inserted occurrence must be freshened.
  -- Under GUC no scope is threaded (see the haddock above): binders are
  -- descended through blindly, so only 'Ref' needs a dedicated case.
  go ∷ RawExp ann → StateT Bool SupplyM (RawExp ann)
  go = \case
    Ref _ann name'
      | name' == name → do
          freshen ← get
          put True
          if freshen then lift (freshenBinders replacement) else pure replacement
    other → traverseOf subexpressions go other

$(makePrisms ''AlgebraicType)
$(makePrisms ''Parameter)
$(makePrisms ''RawExp)
