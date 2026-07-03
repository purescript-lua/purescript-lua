{-# LANGUAGE TemplateHaskell #-}

module Language.PureScript.Backend.IR.Types where

import Control.Lens (Prism', Traversal', makePrisms, prism')
import Data.Deriving (deriveEq1, deriveOrd1)
import Data.Map qualified as Map
import Data.MonoidMap (MonoidMap)
import Data.MonoidMap qualified as MMap
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

-- See Note [Sequential scoping of Let bindings] for what this index selects
newtype Index = Index {unIndex ∷ Natural}
  deriving newtype (Show, Eq, Ord, Num, Enum, Real, Integral)

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
  | Ref ann (Qualified Name) Index
  | Let ann (NonEmpty (Grouping (ann, Name, RawExp ann))) (RawExp ann)
  | IfThenElse ann (RawExp ann) (RawExp ann) (RawExp ann)
  | Exception ann Text
  | ForeignImport ann ModuleName FilePath [(ann, Name)]

{- Note [Sequential scoping of Let bindings]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A local variable is referenced by name plus a De Bruijn-style index
('Ref _ (Local name) index'): the index selects among the binders of
that same name that are in scope, counting from the innermost binder
outwards, starting at 0. The index is per-name, so introducing a binder
for one name does not disturb references to other names.

Which binders of a 'Let' are in scope where? The convention is
sequential, like Scheme's let*:

  * the RHS of a Standalone binding sees the *earlier* siblings of the
    same Let; the binding's own name is NOT in scope there, so a
    reference to it from its own RHS points at an outer binder
    (Standalone bindings are non-recursive);

  * the RHS of a RecursiveGroup member sees the earlier groupings of
    the same Let and every member of its own group, itself included;

  * the body sees all the bindings.

For example (indices in brackets):

  let a = ...           -- sees only the enclosing scope
      b = f a[0]        -- a[0] is the sibling directly above
      a = g a[0] b[0]   -- a[0] is the FIRST binding, not itself
  in h a[0] a[1] b[0]   -- a[0] is the second binding, a[1] the first

Every traversal that walks under Let binders while indices can still be
non-zero — i.e. anything at or upstream of
'Language.PureScript.Backend.IR.Uniquify.uniquifyNames', the pipeline's
entry pass — must implement this convention, and they must all agree:

  * 'countFreeRefs' threads the scope through the groupings left to right;

  * 'alphaEq' resolves (name, index) pairs to binder positions the same
    way, so it stays correct on shadowed input;

  * the well-scopedness lint
    ('Language.PureScript.Backend.IR.Linter.unboundLocals' — the
    requires-contract of 'uniquifyNames' itself, so it must accept
    exactly the pre-GUC shapes) counts binders per name the same way;

  * 'qualifyTopRefs' (Linker, ahead of the optimizer pipeline) decides
    whether a local reference escapes to a top-level binding by
    threading per-name depths the same way;

  * 'Language.PureScript.Backend.IR.Uniquify.uniquifyNamesInExpr'
    resolves (name, index) pairs to fresh, site-wide unique names the
    same way, establishing the global-uniqueness condition (GUC =
    @UniqueBinders@ + @IndicesZero@, issue #139) that every later pass
    requires and preserves.

Once GUC holds, a local reference resolves to its binder by name alone
and every index is 0, so the convention above can no longer produce an
ambiguous resolution — but 'uniquifyNames' itself, and everything
upstream of it, must still get it right. The Lua code generator emits
Standalone bindings of a Let as a sequence of 'local' statements, which
is exactly let* scoping on the Lua side (the Let case of 'fromIR').

Getting one of the walkers wrong miscompiles. Issue #37 was caused by
the pre-GUC 'substitute'\/'shift' (since removed, issue #139)
implementing the opposite convention (own name bound in its own RHS,
siblings ignored): inlining shifted a sibling-bound reference past its
binder, DCE deleted the "unused" binder, and codegen rendered the
dangling 'Ref (Local Bind1) 1' as an undefined Lua variable 'Bind11'.
The golden test test/ps/src/Golden/Issue37/Test.purs and the "Let
sequential (let*) scoping" tests pin the convention.
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
  Ref ann _ _ → ann
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
   in abstraction (paramNamed name) (refLocal name 0)

lets ∷ NonEmpty Binding → Exp → Exp
lets = Let noAnn

application ∷ Exp → Exp → Exp
application = App noAnn

paramNamed ∷ Name → Parameter Ann
paramNamed = ParamNamed noAnn

paramUnused ∷ Parameter Ann
paramUnused = ParamUnused noAnn

ref ∷ Qualified Name → Index → Exp
ref qname index =
  case qname of
    Local name → refLocal name index
    Imported modname name → refImported modname name index

refLocal ∷ Name → Index → Exp
refLocal = Ref noAnn . Local

refLocal0 ∷ Name → Exp
refLocal0 name = refLocal name (Index 0)

refImported ∷ ModuleName → Name → Index → Exp
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
      Ref _ann qname index → pure $ Ref ann qname index
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
    ∷ Map (Qualified Name) Index
    → RawExp ann
    → MonoidMap (Qualified Name) (Sum Natural)
  countFreeRefs' minIndexes = \case
    Ref _ann qname index →
      if Map.findWithDefault 0 qname minIndexes <= index
        then MMap.singleton qname (Sum 1)
        else mempty
    Abs _ann param body →
      case param of
        ParamNamed _paramAnn name → countFreeRefs' minIndexes' body
         where
          minIndexes' = Map.insertWith (+) (Local name) 1 minIndexes
        ParamUnused _paramAnn → countFreeRefs' minIndexes body
    -- See Note [Sequential scoping of Let bindings]
    Let _ann binds body → fold (countsInBody : countsInBinds)
     where
      countsInBody = countFreeRefs' minIndexesAfterBinds body
      (minIndexesAfterBinds, countsInBinds) =
        foldl' withGrouping (minIndexes, []) (toList binds)
      withGrouping
        ∷ ( Map (Qualified Name) Index
          , [MonoidMap (Qualified Name) (Sum Natural)]
          )
        → Grouping (ann, Name, RawExp ann)
        → ( Map (Qualified Name) Index
          , [MonoidMap (Qualified Name) (Sum Natural)]
          )
      withGrouping (mins, counts) = \case
        Standalone (_nameAnn, boundName, expr) →
          ( Map.insertWith (+) (Local boundName) 1 mins
          , countFreeRefs' mins expr : counts
          )
        RecursiveGroup recBinds →
          ( minsAfterGroup
          , ( toList recBinds <&> \(_nameAnn, _boundName, expr) →
                countFreeRefs' minsAfterGroup expr
            )
              <> counts
          )
         where
          minsAfterGroup =
            foldr
              (\(_nameAnn, qName, _expr) → Map.insertWith (+) (Local qName) 1)
              mins
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
    go = countFreeRefs' minIndexes

countFreeRef ∷ Qualified Name → RawExp ann → Natural
countFreeRef name = Map.findWithDefault 0 name . countFreeRefs

{- | Structural equality modulo the names of locally-bound binders.

Two expressions are alpha-equivalent when they differ at most in the
names chosen for the binders they introduce ('Abs' parameters and 'Let'
bindings). Local references are compared by the binder they resolve to,
not by name: bound references must resolve to corresponding binder
positions (binders are numbered in lockstep on both sides), while free
references must agree on the name and on the index remaining after the
locally-bound binders of that name are discounted, because both sides
live in the same enclosing scope. Resolution follows
Note [Sequential scoping of Let bindings].

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
    → Map Name [Natural]
    → Map Name [Natural]
    → RawExp ann
    → RawExp ann
    → Bool
  go lvl scopeL scopeR exprL exprR = case (exprL, exprR) of
    (Ref annL (Local nameL) idxL, Ref annR (Local nameR) idxR) →
      annL == annR
        && case (resolve scopeL nameL idxL, resolve scopeR nameR idxR) of
          (Just levelL, Just levelR) → levelL == levelR
          (Nothing, Nothing) →
            nameL == nameR
              && freeIndex scopeL nameL idxL == freeIndex scopeR nameR idxR
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
    → Map Name [Natural]
    → Map Name [Natural]
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
    → Map Name [Natural]
    → Map Name [Natural]
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

  -- The stack of binder levels for a name, innermost first.
  bindLevel ∷ Name → Natural → Map Name [Natural] → Map Name [Natural]
  bindLevel name lvl = Map.insertWith (<>) name [lvl]

  resolve ∷ Map Name [Natural] → Name → Index → Maybe Natural
  resolve scope name (Index i) =
    Map.findWithDefault [] name scope !!? fromIntegral i

  -- Only defined when 'resolve' failed, so the subtraction can't
  -- underflow: the index is at least the number of local binders.
  freeIndex ∷ Map Name [Natural] → Name → Index → Natural
  freeIndex scope name (Index i) =
    i - fromIntegral (length (Map.findWithDefault [] name scope))

{- | Rename every binder bound /within/ the expression to a fresh
supply-minted name (@\<original\>$\<n\>@ — the @$@ cannot occur in a
source identifier, so a mint can never collide with one), rewriting the
references each binder binds. Free references — bound outside the
expression — are untouched.

Correct only under the GUC discipline (@UniqueBinders@ +
@IndicesZero@): binders within the expression are unique and every
local reference has index 0, so a reference belongs to a binder iff
the names match, and the sequential scoping subtleties of
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
    r@(Ref ann qname index)
      | Local name ← qname
      , Just renamed ← Map.lookup name renames →
          pure (Ref ann (Local renamed) index)
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
the variable (necessarily at index 0) with the replacement. There is no
scope threading and no index arithmetic: under unique binders the
substituted name cannot be rebound inside the target, and the
replacement's free references cannot be captured at any insertion
point. Matched occurrences are replaced, never descended into, so a
replacement referring to the substituted name itself is safe.

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
    r@(Ref _ann name' _index)
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
