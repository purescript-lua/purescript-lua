module Language.PureScript.Backend.IR.Gen where

import Data.List.NonEmpty qualified as NE
import Data.Set qualified as Set
import Data.Text qualified as Text
import Hedgehog (MonadGen)
import Hedgehog.Corpus qualified as Corpus
import Hedgehog.Gen.Extended qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Names qualified as IR
import Language.PureScript.Backend.IR.Types (noAnn)
import Language.PureScript.Backend.IR.Types qualified as IR
import Language.PureScript.Names (ModuleName, moduleNameFromString)
import Prelude hiding (exp)

exp ∷ ∀ m. MonadGen m ⇒ m IR.Exp
exp =
  Gen.recursiveFrequency
    [(1, nonRecursiveExp)]
    [
      ( 7
      , Gen.subterm2 exp exp IR.application
      )
    ,
      ( 3
      , Gen.subterm3 exp exp exp IR.ifThenElse
      )
    ,
      ( 1
      , Gen.subtermM exp \e →
          IR.arrayIndex e <$> Gen.integral (Range.linear 0 9)
      )
    ,
      ( 1
      , Gen.subtermM exp \e → IR.objectProp e <$> genPropName
      )
    ,
      ( 2
      , IR.literalArray <$> Gen.list (Range.linear 1 10) exp
      )
    ,
      ( 2
      , IR.literalObject <$> Gen.list (Range.linear 1 10) ((,) <$> genPropName <*> exp)
      )
    ,
      ( 1
      , Gen.subtermM exp \e →
          IR.objectUpdate e
            <$> Gen.nonEmpty (Range.linear 1 10) ((,) <$> genPropName <*> exp)
      )
    ,
      ( 5
      , Gen.subtermM exp \e → (`IR.abstraction` e) <$> parameter
      )
    ,
      ( 2
      , Gen.subtermM exp \e → (`IR.abstractionN` e) <$> parameters
      )
    ,
      ( 6
      , Gen.subtermM exp \e →
          (`IR.lets` e) <$> Gen.nonEmpty (Range.linear 1 5) binding
      )
    , (3, genCtorApp)
    , (2, IR.reflectCtor <$> genCtorApp)
    ,
      ( 2
      , IR.dataArgumentByIndex
          <$> Gen.integral (Range.linear 0 3)
          <*> genCtorApp
      )
    ]
 where
  -- A saturated constructor application: exactly one argument per field
  -- (nullary ctor ⇒ a bare 'Ctor'). This is the shape the #177
  -- case-of-known-constructor fold matches on, so the fold-firing input
  -- reaches the 'exp'-based suites too.
  genCtorApp = do
    fields ← Gen.list (Range.linear 0 3) fieldName
    ctorExp ←
      IR.ctor
        <$> Gen.enumBounded
        <*> moduleName
        <*> tyName
        <*> ctorName
        <*> pure fields
    args ← forM fields \_field → exp
    pure (foldl' IR.application ctorExp args)

{- | A generation-time scope: the local names with an enclosing binder.
Lets 'scopedExp' emit only references that resolve to a binder.
-}
type Scope = Set IR.Name

{- | Generate a closed, well-scoped expression: every local reference has
an enclosing binder of its name. Covers
λ / application / if / object / reference / scalar / 'Let' — every
binding form, so the properties riding on this generator (uniquify,
freshening, the full optimizer pipeline) see the sequential Let scoping
of Note [Sequential scoping of Let bindings], not just λ-binders.
Well-scopedness stays guaranteed by construction: each case threads the
'Scope' exactly the way the walkers resolve it.
-}
scopedExp ∷ ∀ m. MonadGen m ⇒ m IR.Exp
scopedExp =
  -- Cap the size hard: beta reduction duplicates substituted arguments, so an
  -- unbounded term can blow the optimizer up exponentially in memory. Small
  -- terms are plenty to surface scoping bugs (issues #37 / #56 both shrink to
  -- a handful of binders).
  Gen.scale (min 8) (scopedExpIn mempty)

scopedExpIn ∷ ∀ m. MonadGen m ⇒ Scope → m IR.Exp
scopedExpIn scope =
  Gen.recursiveFrequency
    ((4, scalarExp) : [(5, scopedRef) | not (Set.null scope)])
    [ (6, IR.application <$> scopedExpIn scope <*> scopedExpIn scope)
    ,
      ( 3
      , IR.ifThenElse
          <$> scopedExpIn scope
          <*> scopedExpIn scope
          <*> scopedExpIn scope
      )
    , (5, genAbs)
    , (4, genRedex)
    , (2, genRedexN)
    , (4, genLet)
    ,
      ( 2
      , IR.literalObject
          <$> Gen.list
            (Range.linear 1 4)
            ((,) <$> genPropName <*> scopedExpIn scope)
      )
    , (3, genCtorApp)
    , (2, IR.reflectCtor <$> genCtorApp)
    ,
      ( 2
      , IR.dataArgumentByIndex
          <$> Gen.integral (Range.linear 0 3)
          <*> genCtorApp
      )
    ]
 where
  scopedRef = IR.refLocal <$> Gen.element (Set.toList scope)
  -- A saturated constructor application: exactly one argument per field
  -- (nullary ctor ⇒ a bare 'Ctor'). A 'Ctor' node binds nothing and
  -- references no 'Scope' entry, so every argument just reuses the
  -- incoming scope — the same category as application / if / object.
  -- This is the shape the #177 case-of-known-constructor fold matches on.
  genCtorApp = do
    fields ← Gen.list (Range.linear 0 3) fieldName
    ctorExp ←
      IR.ctor
        <$> Gen.enumBounded
        <*> moduleName
        <*> tyName
        <*> ctorName
        <*> pure fields
    args ← forM fields \_field → scopedExpIn scope
    pure (foldl' IR.application ctorExp args)
  genAbs = do
    (param, body) ← genBinderBody
    pure (IR.abstraction param body)
  -- An immediately-applied λ: a beta redex. Generating these directly (rather
  -- than hoping an application's head happens to be a λ) is what makes the
  -- well-scopedness property actually exercise beta reduction, including the
  -- shadowing case behind issue #56.
  genRedex = do
    (param, body) ← genBinderBody
    arg ← scopedExpIn scope
    pure (IR.application (IR.abstraction param body) arg)
  genBinderBody = do
    param ← parameter
    let scope' = case param of
          IR.ParamNamed _ nm → Set.insert nm scope
          IR.ParamUnused _ → scope
    body ← scopedExpIn scope'
    pure (param, body)
  -- An exactly-saturated application of an n-ary lambda — the only shape
  -- a multi-parameter 'AbsN' may be applied in ('WellApplied', see
  -- Note [n-ary abstraction]). Generated as a redex so the generic
  -- application case above cannot pair the lambda with a wrong argument
  -- count.
  genRedexN = do
    names ← Gen.nonEmpty (Range.linear 2 3) name
    let scope' = foldr Set.insert scope (toList names)
    body ← scopedExpIn scope'
    args ← forM names \_nm → scopedExpIn scope
    pure
      ( IR.applicationN
          (IR.abstractionN (IR.paramNamed <$> names) body)
          args
      )
  -- A Let with 1–3 groupings. The scope threads sequentially, following
  -- Note [Sequential scoping of Let bindings]. Names come from the same
  -- small pool as everywhere else, so shadowing and parallel duplicates
  -- arise naturally.
  genLet ∷ m IR.Exp
  genLet = do
    (grouping, scope') ← genGrouping scope
    rest ← Gen.int (Range.linear 0 2)
    (groupings, scope'') ← genGroupings rest scope'
    body ← scopedExpIn scope''
    pure (IR.lets (grouping :| groupings) body)
  genGroupings ∷ Int → Scope → m ([IR.Binding], Scope)
  genGroupings n sc
    | n <= 0 = pure ([], sc)
    | otherwise = do
        (grouping, sc') ← genGrouping sc
        (groupings, sc'') ← genGroupings (n - 1) sc'
        pure (grouping : groupings, sc'')
  genGrouping ∷ Scope → m (IR.Binding, Scope)
  genGrouping sc = Gen.frequency [(7, genStandalone sc), (3, genRecGroup sc)]
  -- A Standalone RHS does not see its own binder: it is generated under
  -- the incoming scope, and the name is bound only afterwards.
  genStandalone ∷ Scope → m (IR.Binding, Scope)
  genStandalone sc = do
    nm ← name
    rhs ← scopedExpIn sc
    pure (IR.Standalone (noAnn, nm, rhs), bindName nm sc)
  -- Every member of a recursive group is in scope in every member's RHS.
  -- Names within one group are distinct ('Gen.set'): same-named members
  -- of a single group are meaningless and CoreFn never produces them.
  genRecGroup ∷ Scope → m (IR.Binding, Scope)
  genRecGroup sc = do
    names ← Gen.set (Range.linear 1 3) name
    let sc' = foldr bindName sc names
    members ← forM (toList names) \nm → (noAnn,nm,) <$> scopedExpIn sc'
    -- NE.fromList is safe: 'names' has at least one element.
    pure (IR.RecursiveGroup (NE.fromList members), sc')
  bindName ∷ IR.Name → Scope → Scope
  bindName = Set.insert

binding ∷ MonadGen m ⇒ m IR.Binding
binding = Gen.frequency [(8, standaloneBinding), (2, recursiveBinding)]

namedExp ∷ MonadGen m ⇒ m (IR.Ann, IR.Name, IR.Exp)
namedExp = (noAnn,,) <$> name <*> exp

recursiveBinding ∷ MonadGen m ⇒ m IR.Binding
recursiveBinding =
  IR.RecursiveGroup <$> Gen.nonEmpty (Range.linear 1 5) namedExp

standaloneBinding ∷ MonadGen m ⇒ m IR.Binding
standaloneBinding = IR.Standalone <$> namedExp

nonRecursiveExp ∷ MonadGen m ⇒ m IR.Exp
nonRecursiveExp =
  Gen.frequency
    [ (5, literalNonRecursiveExp)
    , (1, exception)
    , (1, ctor)
    , (3, IR.ref <$> qualified name)
    ]

exception ∷ MonadGen m ⇒ m IR.Exp
exception = IR.exception <$> Gen.text (Range.linear 0 10) Gen.unicode

ctor ∷ MonadGen m ⇒ m IR.Exp
ctor =
  IR.ctor
    <$> Gen.enumBounded
    <*> moduleName
    <*> tyName
    <*> ctorName
    <*> Gen.list (Range.linear 0 10) fieldName

literalNonRecursiveExp ∷ MonadGen m ⇒ m IR.Exp
literalNonRecursiveExp =
  Gen.frequency
    [ (5, scalarExp)
    , (1, pure $ IR.literalArray [])
    , (1, pure $ IR.literalObject [])
    ]

scalarExp ∷ MonadGen m ⇒ m IR.Exp
scalarExp =
  Gen.choice
    [ IR.literalInt <$> Gen.integral (Range.exponential 0 1000)
    , IR.literalString <$> Gen.text (Range.linear 0 10) Gen.unicode
    , IR.literalBool <$> Gen.bool
    , IR.literalChar <$> Gen.unicode
    , IR.literalFloat
        <$> Gen.double
          (Range.exponentialFloat 0 1000000000000000000)
    ]

parameter ∷ MonadGen m ⇒ m (IR.Parameter IR.Ann)
parameter =
  Gen.frequency
    [ (1, pure (IR.ParamUnused noAnn))
    , (9, IR.ParamNamed noAnn <$> name)
    ]

{- | A multi-parameter list for an 'AbsN': named parameters with an
optional trailing 'ParamUnused' run — the only well-formed placement
(Note [n-ary abstraction]).
-}
parameters ∷ MonadGen m ⇒ m (NonEmpty (IR.Parameter IR.Ann))
parameters = do
  named ← Gen.nonEmpty (Range.linear 2 3) (IR.paramNamed <$> name)
  unusedCount ← Gen.int (Range.linear 0 1)
  pure (NE.appendList named (replicate unusedCount IR.paramUnused))

qualified ∷ MonadGen m ⇒ m a → m (IR.Qualified a)
qualified q =
  Gen.frequency
    [ (8, IR.Local <$> q)
    , (2, IR.Imported <$> moduleName <*> q)
    ]

refLocal ∷ MonadGen m ⇒ m IR.Exp
refLocal = IR.refLocal <$> name

moduleName ∷ MonadGen m ⇒ m ModuleName
moduleName = moduleNameFromString <$> Gen.element Corpus.colours

name ∷ MonadGen m ⇒ m IR.Name
name = IR.Name <$> Gen.element ["x", "y", "z", "i", "j", "k", "l"]

tyName ∷ MonadGen m ⇒ m IR.TyName
tyName = IR.TyName . Text.toTitle <$> Gen.element Corpus.waters

ctorName ∷ MonadGen m ⇒ m IR.CtorName
ctorName = IR.CtorName . Text.toTitle <$> Gen.element Corpus.colours

genPropName ∷ MonadGen m ⇒ m IR.PropName
genPropName = IR.PropName <$> Gen.element Corpus.metasyntactic

fieldName ∷ MonadGen m ⇒ m IR.FieldName
fieldName = IR.FieldName <$> Gen.element Corpus.metasyntactic
