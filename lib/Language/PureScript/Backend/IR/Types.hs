{-# LANGUAGE TemplateHaskell #-}

module Language.PureScript.Backend.IR.Types where

import Control.Lens (Prism', Traversal', makePrisms, prism')
import Data.Deriving (deriveEq1, deriveOrd1)
import Data.Map qualified as Map
import Data.MonoidMap (MonoidMap)
import Data.MonoidMap qualified as MMap
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Inliner qualified as Inliner
import Language.PureScript.Backend.IR.Names
  ( CtorName (renderCtorName)
  , FieldName
  , ModuleName
  , Name (Name, nameToText)
  , PropName
  , Qualified (..)
  , TyName (renderTyName)
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
  deriving stock (Show, Eq, Ord)

paramName ∷ Parameter ann → Maybe Name
paramName (ParamUnused _ann) = Nothing
paramName (ParamNamed _ann name) = Just name

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
  | DataArgumentByIndex ann Natural (RawExp ann)
  | ArrayLength ann (RawExp ann)
  | ArrayIndex ann (RawExp ann) Natural
  | ObjectProp ann (RawExp ann) PropName
  | ObjectUpdate ann (RawExp ann) (NonEmpty (PropName, RawExp ann))
  | Abs ann (Parameter ann) (RawExp ann)
  | App ann (RawExp ann) (RawExp ann)
  | Ref ann (Qualified Name)
  | Let ann (NonEmpty (Grouping (ann, Name, RawExp ann))) (RawExp ann)
  | IfThenElse ann (RawExp ann) (RawExp ann) (RawExp ann)
  | Exception ann Text
  | ForeignImport ann ModuleName FilePath [(ann, Name)]

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
  DataArgumentByIndex ann _ _ → ann
  ArrayLength ann _ → ann
  ArrayIndex ann _ _ → ann
  ObjectProp ann _ _ → ann
  ObjectUpdate ann _ _ → ann
  Abs ann _ _ → ann
  App ann _ _ → ann
  Ref ann _ → ann
  Let ann _ _ → ann
  IfThenElse ann _ _ _ → ann
  Exception ann _ → ann
  ForeignImport ann _ _ _ → ann

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

identity ∷ Exp
identity =
  let name = Name "x"
   in abstraction (paramNamed name) (refLocal name)

lets ∷ NonEmpty Binding → Exp → Exp
lets = Let noAnn

application ∷ Exp → Exp → Exp
application = App noAnn

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

arrayLength ∷ Exp → Exp
arrayLength = ArrayLength noAnn

reflectCtor ∷ Exp → Exp
reflectCtor = ReflectCtor noAnn

dataArgumentByIndex ∷ Natural → Exp → Exp
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

annotateExpM
  ∷ ∀ ann ann' m
   . Monad m
  ⇒ (∀ x. m x → m x)
  → (RawExp ann → m ann')
  → (Parameter ann → m (Parameter ann'))
  → (ann → Name → m ann')
  → (RawExp ann → m (RawExp ann'))
annotateExpM around annotateExp annotateParam annotateName =
  around . \expr → do
    ann ← annotateExp expr
    case expr of
      LiteralInt _ann i →
        pure $ LiteralInt ann i
      LiteralFloat _ann f →
        pure $ LiteralFloat ann f
      LiteralString _ann s →
        pure $ LiteralString ann s
      LiteralChar _ann c →
        pure $ LiteralChar ann c
      LiteralBool _ann b →
        pure $ LiteralBool ann b
      LiteralArray _ann elems → do
        elems' ← traverse mkAnn elems
        pure $ LiteralArray ann elems'
      LiteralObject _ann props → do
        props' ← traverse (traverse mkAnn) props
        pure $ LiteralObject ann props'
      ReflectCtor _ann a → do
        a' ← mkAnn a
        pure $ ReflectCtor ann a'
      Eq _ann a b → do
        a' ← mkAnn a
        b' ← mkAnn b
        pure $ Eq ann a' b'
      DataArgumentByIndex _ann index a → do
        a' ← mkAnn a
        pure $ DataArgumentByIndex ann index a'
      ArrayLength _ann a → do
        a' ← mkAnn a
        pure $ ArrayLength ann a'
      ArrayIndex _ann a index → do
        a' ← mkAnn a
        pure $ ArrayIndex ann a' index
      ObjectProp _ann a prop → do
        a' ← mkAnn a
        pure $ ObjectProp ann a' prop
      ObjectUpdate _ann a props → do
        a' ← mkAnn a
        props' ← traverse (traverse mkAnn) props
        pure $ ObjectUpdate ann a' props'
      Abs _ann param body → do
        body' ← mkAnn body
        param' ← annotateParam param
        pure $ Abs ann param' body'
      App _ann a b → do
        a' ← mkAnn a
        b' ← mkAnn b
        pure $ App ann a' b'
      Ref _ann qname → pure $ Ref ann qname
      Let _ann binds body → do
        binds' ←
          forM binds $
            traverse \(a, n, e) → do
              n' ← annotateName a n
              e' ← mkAnn e
              pure (n', n, e')
        body' ← mkAnn body
        pure $ Let ann binds' body'
      IfThenElse _ann i t e → do
        i' ← mkAnn i
        t' ← mkAnn t
        e' ← mkAnn e
        pure $ IfThenElse ann i' t' e'
      Ctor _ann mn aty ty ctr fs → pure $ Ctor ann mn aty ty ctr fs
      Exception _ann m → pure $ Exception ann m
      ForeignImport _ann m p ns → do
        anns ← traverse (uncurry annotateName) ns
        let ns' = zip anns (fmap snd ns)
        pure $ ForeignImport ann m p ns'
 where
  mkAnn ∷ RawExp ann → m (RawExp ann')
  mkAnn = annotateExpM around annotateExp annotateParam annotateName

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
  DataArgumentByIndex ann idx a →
    DataArgumentByIndex ann idx <$> go a
  Eq ann a b →
    Eq ann <$> go a <*> go b
  ArrayLength ann a →
    ArrayLength ann <$> go a
  ArrayIndex ann a idx →
    ArrayIndex ann <$> go a <*> pure idx
  ObjectProp ann a prp →
    ObjectProp ann <$> go a <*> pure prp
  ObjectUpdate ann a ps →
    ObjectUpdate ann <$> go a <*> traverse (traverse go) ps
  App ann a b →
    App ann <$> go a <*> go b
  Abs ann arg a →
    Abs ann arg <$> go a
  Let ann bs body →
    Let ann
      <$> traverse (traverse (\(a, n, expr) → (a,n,) <$> go expr)) bs
      <*> go body
  IfThenElse ann p th el →
    IfThenElse ann <$> go p <*> go th <*> go el
  e → pure e

data RewriteMod = Recurse | Stop
  deriving stock (Show, Eq, Ord)

instance Semigroup RewriteMod where
  Recurse <> Recurse = Recurse
  _ <> _ = Stop

data Rewritten a = NoChange | Rewritten RewriteMod a
  deriving stock (Show, Eq, Ord, Functor)

instance Applicative Rewritten where
  pure ∷ ∀ a. a → Rewritten a
  pure = Rewritten Stop
  NoChange <*> _ = NoChange
  _ <*> NoChange = NoChange
  Rewritten rmf f <*> Rewritten rma a = Rewritten (rmf <> rma) (f a)

instance Monad Rewritten where
  NoChange >>= _ = NoChange
  Rewritten m a >>= f = case f a of
    NoChange → NoChange
    Rewritten m' a' → Rewritten (m <> m') a'

instance Alternative Rewritten where
  empty = NoChange
  NoChange <|> a = a
  a <|> _ = a

type RewriteRule ann = RewriteRuleM Identity ann
type RewriteRuleM m ann = RawExp ann → m (Rewritten (RawExp ann))

thenRewrite
  ∷ Monad m
  ⇒ RewriteRuleM m ann
  → RewriteRuleM m ann
  → RewriteRuleM m ann
thenRewrite rewrite1 rewrite2 e =
  rewrite1 e >>= \case
    Rewritten m' e' → do
      rewrite2 e' <&> \case
        NoChange → Rewritten m' e'
        Rewritten m'' e'' → Rewritten (m' <> m'') e''
    NoChange → rewrite2 e

rewriteExpTopDown ∷ RewriteRuleM Identity ann → RawExp ann → RawExp ann
rewriteExpTopDown rewrite = runIdentity . rewriteExpTopDownM rewrite

rewriteExpTopDownM ∷ Monad m ⇒ RewriteRuleM m ann → RawExp ann → m (RawExp ann)
rewriteExpTopDownM rewrite = visit
 where
  visit expression =
    rewrite expression >>= \case
      NoChange → descendInto expression
      Rewritten Stop expression' → pure expression'
      Rewritten Recurse expression' → descendInto expression'

  descendInto e = case e of
    LiteralArray ann as →
      LiteralArray ann <$> traverse visit as
    LiteralObject ann props →
      LiteralObject ann <$> traverse (traverse visit) props
    ReflectCtor ann a →
      ReflectCtor ann <$> visit a
    DataArgumentByIndex ann idx a →
      DataArgumentByIndex ann idx <$> visit a
    Eq ann a b →
      Eq ann <$> visit a <*> visit b
    ArrayLength ann a →
      ArrayLength ann <$> visit a
    ArrayIndex ann a indx →
      visit a <&> \expr → ArrayIndex ann expr indx
    ObjectProp ann a prop →
      visit a <&> \expr → ObjectProp ann expr prop
    ObjectUpdate ann a patches →
      ObjectUpdate ann <$> visit a <*> traverse (traverse visit) patches
    App ann a b →
      App ann <$> visit a <*> visit b
    Abs ann param expr →
      Abs ann param <$> visit expr
    Let ann binds body →
      Let ann
        <$> forM binds (traverse \(a, n, expr) → (a,n,) <$> visit expr)
        <*> visit body
    IfThenElse ann p th el →
      IfThenElse ann <$> visit p <*> visit th <*> visit el
    _ → pure e

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
    Abs _ann param body →
      case param of
        ParamNamed _paramAnn name →
          countFreeRefs' (Set.insert name bound) body
        ParamUnused _paramAnn → countFreeRefs' bound body
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
    App _ann argument function →
      go argument <> go function
    LiteralArray _ann as →
      foldMap go as
    LiteralObject _ann props →
      foldMap (go . snd) props
    ReflectCtor _ann a →
      go a
    DataArgumentByIndex _ann _idx a →
      go a
    Eq _ann a b →
      go a <> go b
    ArrayLength _ann a →
      go a
    ArrayIndex _ann a _indx →
      go a
    ObjectProp _ann a _prop →
      go a
    ObjectUpdate _ann a patches →
      go a <> foldMap (go . snd) patches
    IfThenElse _ann p th el →
      go p <> go th <> go el
    -- Terminals:
    LiteralInt {} → mempty
    LiteralBool {} → mempty
    LiteralFloat {} → mempty
    LiteralString {} → mempty
    LiteralChar {} → mempty
    Ctor {} → mempty
    Exception {} → mempty
    ForeignImport {} → mempty
   where
    go = countFreeRefs' bound

countFreeRef ∷ Qualified Name → RawExp ann → Natural
countFreeRef name = Map.findWithDefault 0 name . countFreeRefs

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
    (Abs annL paramL bodyL, Abs annR paramR bodyR) →
      annL == annR && case (paramL, paramR) of
        (ParamUnused paL, ParamUnused paR) →
          paL == paR && go lvl scopeL scopeR bodyL bodyR
        (ParamNamed paL nameL, ParamNamed paR nameR) →
          paL == paR
            && go
              (lvl + 1)
              (bindLevel nameL lvl scopeL)
              (bindLevel nameR lvl scopeR)
              bodyL
              bodyR
        _ → False
    (Let annL bindsL bodyL, Let annR bindsR bodyR) →
      annL == annR
        && goLet lvl scopeL scopeR (toList bindsL) (toList bindsR) bodyL bodyR
    (App annL fL aL, App annR fR aR) →
      annL == annR && go lvl scopeL scopeR fL fR && go lvl scopeL scopeR aL aR
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
    (DataArgumentByIndex annL iL aL, DataArgumentByIndex annR iR aR) →
      annL == annR && iL == iR && go lvl scopeL scopeR aL aR
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
    Abs ann param body →
      case param of
        ParamUnused _paramAnn → Abs ann param <$> go renames body
        ParamNamed paramAnn name → do
          name' ← freshNameFor name
          Abs ann (ParamNamed paramAnn name')
            <$> go (Map.insert name name' renames) body
    Let ann binds body → do
      -- Under unique binders no Let name can be referenced before it is
      -- bound, so all the groupings can enter the rename map up front.
      renames' ←
        foldlM
          ( \rs name → do
              name' ← freshNameFor name
              pure (Map.insert name name' rs)
          )
          renames
          (bindingNames =<< toList binds)
      let renameBound (bindAnn, name, expr) =
            (bindAnn,Map.findWithDefault name name renames',)
              <$> go renames' expr
      Let ann <$> traverse (traverse renameBound) binds <*> go renames' body
    LiteralArray ann as →
      LiteralArray ann <$> traverse (go renames) as
    LiteralObject ann props →
      LiteralObject ann <$> traverse (traverse (go renames)) props
    ReflectCtor ann a →
      ReflectCtor ann <$> go renames a
    DataArgumentByIndex ann idx a →
      DataArgumentByIndex ann idx <$> go renames a
    Eq ann a b →
      Eq ann <$> go renames a <*> go renames b
    ArrayLength ann a →
      ArrayLength ann <$> go renames a
    ArrayIndex ann a idx →
      ArrayIndex ann <$> go renames a <*> pure idx
    ObjectProp ann a prop →
      ObjectProp ann <$> go renames a <*> pure prop
    ObjectUpdate ann a patches →
      ObjectUpdate ann <$> go renames a <*> traverse (traverse (go renames)) patches
    App ann a b →
      App ann <$> go renames a <*> go renames b
    IfThenElse ann p th el →
      IfThenElse ann <$> go renames p <*> go renames th <*> go renames el
    -- Terminals:
    terminal → pure terminal

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
  go ∷ RawExp ann → StateT Bool SupplyM (RawExp ann)
  go = \case
    r@(Ref _ann name')
      | name' == name → do
          freshen ← get
          put True
          if freshen then lift (freshenBinders replacement) else pure replacement
      | otherwise → pure r
    Abs ann param body →
      Abs ann param <$> go body
    Let ann binds body →
      Let ann
        <$> traverse (traverse \(a, n, expr) → (a,n,) <$> go expr) binds
        <*> go body
    LiteralArray ann as →
      LiteralArray ann <$> traverse go as
    LiteralObject ann props →
      LiteralObject ann <$> traverse (traverse go) props
    ReflectCtor ann a →
      ReflectCtor ann <$> go a
    DataArgumentByIndex ann idx a →
      DataArgumentByIndex ann idx <$> go a
    Eq ann a b →
      Eq ann <$> go a <*> go b
    ArrayLength ann a →
      ArrayLength ann <$> go a
    ArrayIndex ann a idx →
      ArrayIndex ann <$> go a <*> pure idx
    ObjectProp ann a prop →
      ObjectProp ann <$> go a <*> pure prop
    ObjectUpdate ann a patches →
      ObjectUpdate ann <$> go a <*> traverse (traverse go) patches
    App ann a b →
      App ann <$> go a <*> go b
    IfThenElse ann p th el →
      IfThenElse ann <$> go p <*> go th <*> go el
    -- Terminals:
    terminal → pure terminal

$(makePrisms ''AlgebraicType)
$(makePrisms ''Parameter)
$(makePrisms ''RawExp)
