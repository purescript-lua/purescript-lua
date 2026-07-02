module Language.PureScript.Backend.IR.Optimizer.Spec where

import Control.Lens (toListOf, universeOf)
import Data.Map qualified as Map
import Hedgehog (PropertyT, annotateShow, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Inliner (Annotation (Never))
import Language.PureScript.Backend.IR.Linker (LinkMode (..))
import Language.PureScript.Backend.IR.Linker qualified as Linker
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , PropName (..)
  , QName (..)
  , Qualified (Local)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Optimizer
  ( optimizedExpression
  , optimizedUberModule
  , renameShadowedNamesInExpr
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , Index
  , Module (..)
  , RawExp (..)
  , abstraction
  , application
  , eq
  , exception
  , ifThenElse
  , isLiteral
  , lets
  , literalBool
  , literalInt
  , literalObject
  , noAnn
  , paramName
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , refLocal0
  , subexpressions
  , unIndex
  )
import Test.Hspec (Spec, SpecWith, describe, it)
import Test.Hspec.Hedgehog (hedgehog, modifyMaxShrinks, modifyMaxSuccess)
import Test.Hspec.Hedgehog.Extended (test)

-- | Like 'test', but runs the property over many generated inputs.
prop ∷ String → PropertyT IO () → SpecWith ()
prop title =
  modifyMaxShrinks (const 20)
    . modifyMaxSuccess (const 100)
    . it title
    . hedgehog

{- | Local references whose De Bruijn index points past every enclosing binder
of that name: unbound locals, which the Lua backend rejects (see
Note [Locals are uniquely named after renameShadowedNames]). An empty result
means the expression is well-scoped. The binder bookkeeping mirrors
'shift'/'unshift'; see Note [Sequential scoping of Let bindings] for 'Let'.
-}
unboundLocals ∷ Exp → [(Name, Index)]
unboundLocals = go Map.empty
 where
  go ∷ Map Name Natural → Exp → [(Name, Index)]
  go scope = \case
    Ref _ (Local nm) index
      | unIndex index < Map.findWithDefault 0 nm scope → []
      | otherwise → [(nm, index)]
    Abs _ param body → go (bindName (paramName param) scope) body
    Let _ binds body →
      let (bodyScope, errs) = foldl' letGrouping (scope, []) (toList binds)
       in errs <> go bodyScope body
    other → foldMap (go scope) (toListOf subexpressions other)
   where
    bindName ∷ Maybe Name → Map Name Natural → Map Name Natural
    bindName Nothing sc = sc
    bindName (Just nm) sc = Map.insertWith (+) nm 1 sc

    letGrouping
      ∷ (Map Name Natural, [(Name, Index)])
      → Grouping (a, Name, Exp)
      → (Map Name Natural, [(Name, Index)])
    letGrouping (sc, errs) = \case
      Standalone (_ann, nm, e) →
        ( Map.insertWith (+) nm 1 sc
        , errs <> go sc e
        )
      RecursiveGroup recBinds →
        ( sc'
        , errs <> foldMap (\(_ann, _nm, e) → go sc' e) recBinds
        )
       where
        sc' = foldr (\nm → Map.insertWith (+) nm 1) sc names
        names = (\(_ann, nm, _e) → nm) <$> toList recBinds

spec ∷ Spec
spec = describe "IR Optimizer" do
  describe "optimizes expressions" do
    test "removes redundant else branch" do
      thenBranch ← forAll Gen.exp
      elseBranch ← forAll Gen.exp
      let ifThenElseStatement = ifThenElse (literalBool True) thenBranch elseBranch
      annotateShow ifThenElseStatement
      thenBranch === optimizedExpression ifThenElseStatement

    test "removes redundant then branch" do
      thenBranch ← forAll Gen.exp
      elseBranch ← forAll Gen.exp
      let ifThenElseStatement = ifThenElse (literalBool False) thenBranch elseBranch
      annotateShow ifThenElseStatement
      elseBranch === optimizedExpression ifThenElseStatement

    test "eliminates argument if corresponding parameter is unused" do
      body ← forAll Gen.nonRecursiveExp
      arg ← forAll Gen.exp
      let f = abstraction paramUnused body
      body === optimizedExpression (application f arg)

    -- See Note [Eta reduction is unsound]
    test "does not eta-reduce λx. M x to M" do
      param ← forAll Gen.name
      let dict = moduleNameFromString "Dict"
          m =
            application
              (refImported dict (Name "eqList") 0)
              (refImported dict (Name "eqInt") 0)
          original = abstraction (paramNamed param) (application m (refLocal0 param))
      optimizedExpression original === original

  describe "inlines expressions" do
    test "inlines literals" do
      name ← forAll Gen.name
      inlinee ← forAll Gen.scalarExp
      let original = let1 name inlinee (refLocal0 name)
          expected = let1 name inlinee inlinee
      optimizedExpression original === expected

    test "inlines references" do
      name ← forAll Gen.name
      inlinee ← forAll Gen.refLocal
      let original = let1 name inlinee (refLocal0 name)
          expected = let1 name inlinee inlinee
      optimizedExpression original === expected

    test "inlines expressions referenced once" do
      name ← forAll Gen.name
      inlinee ← forAll $ fmap optimizedExpression do
        mfilter (\e → not (isRef e || isLiteral e)) Gen.exp
      let body = refLocal0 name
          original = let1 name inlinee body
          expected = let1 name inlinee inlinee
      annotateShow body
      optimizedExpression original === expected

    test "doesn't inline expressions referenced more than once" do
      name ← forAll Gen.name
      inlinee ← forAll $ Gen.choice [Gen.exception, Gen.ctor]
      let original =
            let1 name inlinee $
              application (refLocal0 name) (refLocal0 name)
      annotateShow original
      optimizedExpression original === original

  describe "respects @inline never (issue #131)" do
    test "keeps a never-annotated top-level binding instead of inlining it" do
      let mainModule = moduleNameFromString "Main"
          -- foo = (1 == 1) with `@inline never`. Constant folding rewrites the
          -- root to `true` (dropping the annotation) and foo is used once, so
          -- without a name-based veto it would be inlined away.
          fooExp = Eq (Just Never) (literalInt 1) (literalInt 1)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [Standalone (QName mainModule (Name "foo"), fooExp)]
              , uberModuleExports =
                  [(Name "main", refImported mainModule (Name "foo") 0)]
              }
          optimized = optimizedUberModule original
          fooKept =
            [ qn
            | Standalone (qn, _) ← Linker.uberModuleBindings optimized
            , qn == QName mainModule (Name "foo")
            ]
      annotateShow optimized
      fooKept === [QName mainModule (Name "foo")]

  describe "inliner unlocks more optimizations" do
    test "constant folding after inlining" do
      name ← forAll Gen.name
      let uberName = moduleNameFromString "Main"
          linkMode = LinkAsModule uberName
          mkUber = Linker.makeUberModule linkMode . pure . wrapInModule
      let original =
            mkUber $
              let1 name (literalInt 42) $
                ifThenElse
                  (eq (refLocal0 name) (literalInt 42))
                  (literalInt 1)
                  (literalInt 2)
          expected =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "main", literalInt 1)]
              }
      annotateShow original
      annotateShow expected
      optimizedUberModule original === expected

  describe "scoping invariants" do
    -- Mimics issue #37: an inlined binding contains a let with a
    -- reference bound by an earlier sibling; inlining it under a binder
    -- with the same name must not leave the reference unbound.
    -- See Note [Sequential scoping of Let bindings]
    test "inlining bindings does not unbind let-bound references" do
      let mainModule = moduleNameFromString "Main"
          dict = moduleNameFromString "Dict"
          fooExp =
            abstraction (paramNamed (Name "fn1")) $
              lets
                ( Standalone
                    ( noAnn
                    , Name "Bind1"
                    , application
                        (refImported dict (Name "bind") 0)
                        (refLocal (Name "fn1") 0)
                    )
                    :| [ Standalone
                           ( noAnn
                           , Name "discard1"
                           , application
                               (refImported dict (Name "discard") 0)
                               (refLocal (Name "Bind1") 0)
                           )
                       ]
                )
                ( application
                    (refLocal (Name "discard1") 0)
                    (refLocal (Name "discard1") 0)
                )
          barExp =
            abstraction (paramNamed (Name "f")) $
              lets
                ( Standalone
                    ( noAnn
                    , Name "Bind1"
                    , application
                        (refImported dict (Name "bind") 0)
                        (refLocal (Name "f") 0)
                    )
                    :| []
                )
                ( application
                    ( application
                        (refImported mainModule (Name "foo") 0)
                        (refLocal (Name "f") 0)
                    )
                    ( application
                        (refLocal (Name "Bind1") 0)
                        (refLocal (Name "Bind1") 0)
                    )
                )
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [ Standalone (QName mainModule (Name "foo"), fooExp)
                  , Standalone (QName mainModule (Name "bar"), barExp)
                  ]
              , uberModuleExports =
                  [
                    ( Name "baz"
                    , application
                        (refImported mainModule (Name "bar") 0)
                        (literalInt 7)
                    )
                  ]
              }
          optimized = optimizedUberModule original
          unboundLocalRefs =
            [ (name, index)
            | (_exportedName, expr) ← Linker.uberModuleExports optimized
            , Ref _ann (Local name) index ← universeOf subexpressions expr
            , index /= 0
            ]
      annotateShow optimized
      unboundLocalRefs === []

    -- Issue #56: beta reduction removes a binder, so any reference that the
    -- substitution shifted past it must be lowered back. Here `b` is bound by
    -- an outer λ, while the reduced inner λ is *also* named `b`; reducing it
    -- must drop the outer reference from index 1 back to 0 rather than leave it
    -- unbound. This is the IR shape `Data.Array.foldRecM` boils down to.
    test "beta reduction does not unbind a reference shadowed by the binder" do
      let a = Name "a"
          b = Name "b"
          inner =
            abstraction (paramNamed a) $
              abstraction (paramNamed b) $
                literalObject
                  [ (PropName "p", refLocal a 0)
                  , (PropName "q", refLocal b 0)
                  ]
          -- (\b -> (\a -> \b -> { p: a, q: b }) b 0)
          shadowed =
            abstraction (paramNamed b) $
              application
                (application inner (refLocal b 0))
                (literalInt 0)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "foldRecMShape", shadowed)]
              }
          -- After the redexes are reduced only the outer λ remains, so the
          -- surviving reference is `b` at index 0.
          expected =
            abstraction (paramNamed b) $
              literalObject
                [ (PropName "p", refLocal b 0)
                , (PropName "q", literalInt 0)
                ]
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []
      Linker.uberModuleExports optimized === [(Name "foldRecMShape", expected)]

    -- Sibling of #56 in the DCE pass (found by the property below). Dead-code
    -- elimination blanks an unused named binder to ParamUnused. Here the inner
    -- λj is unused, yet the body references the *outer* j (at index 1, skipping
    -- the inner one); blanking the inner binder must lower that reference to 0,
    -- otherwise it is left unbound.
    test "blanking an unused shadowing binder keeps outer references bound" do
      let j = Name "j"
          k = Name "k"
          -- \j -> (\k -> { foo: (\_ -> \j -> k) 0 }) j
          shadowed =
            abstraction (paramNamed j) $
              application
                ( abstraction (paramNamed k) $
                    literalObject
                      [
                        ( PropName "foo"
                        , application
                            ( abstraction paramUnused $
                                abstraction (paramNamed j) (refLocal k 0)
                            )
                            (literalInt 0)
                        )
                      ]
                )
                (refLocal j 0)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "shape", shadowed)]
              }
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []

    -- The general invariant behind #37 and #56: optimizing a well-scoped
    -- expression must never produce an unbound local reference. Runs through the
    -- whole 'optimizedUberModule' pipeline (not a single 'optimizedExpression'
    -- pass) because the #56 dangling reference only surfaces once an enclosing
    -- redex is reduced on a later iteration.
    prop "optimization keeps expressions well-scoped" do
      e ← forAll Gen.scopedExp
      annotateShow e
      unboundLocals e === [] -- the generator only emits well-scoped terms
      let optimized =
            optimizedUberModule
              Linker.UberModule
                { Linker.uberModuleForeigns = []
                , Linker.uberModuleBindings = []
                , Linker.uberModuleExports = [(Name "root", e)]
                }
      foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized) === []

  describe "renames shadowed names" do
    test "nested λ-abstractions" do
      name ← forAll Gen.name
      let
        name1 = Name $ nameToText name <> "1"
        name2 = Name $ nameToText name <> "2"
        name3 = Name $ nameToText name <> "3"

      let original =
            abstraction
              (paramNamed name)
              ( abstraction
                  (paramNamed name)
                  ( application
                      (refLocal name 0)
                      ( abstraction
                          (paramNamed name)
                          ( abstraction
                              (paramNamed name1)
                              ( application
                                  (refLocal name 0)
                                  (refLocal name 2)
                              )
                          )
                      )
                  )
              )

          renamed =
            abstraction
              (paramNamed name)
              ( abstraction
                  (paramNamed name2)
                  ( application
                      (refLocal name2 0)
                      ( abstraction
                          (paramNamed name3)
                          ( abstraction
                              (paramNamed name1)
                              ( application
                                  (refLocal name3 0)
                                  (refLocal name 0)
                              )
                          )
                      )
                  )
              )
      renameShadowedNamesInExpr mempty original === renamed

    test "nested let-bindings" do
      nameA ← forAll Gen.name
      nameB ← forAll $ mfilter (/= nameA) Gen.name
      valueA ← forAll Gen.literalNonRecursiveExp
      valueB ← forAll Gen.literalNonRecursiveExp
      let original =
            lets
              (Standalone (noAnn, nameA, valueA) :| [Standalone (noAnn, nameB, valueB)])
              ( lets
                  ( Standalone (noAnn, nameA, refLocal nameA 0)
                      :| [Standalone (noAnn, nameB, refLocal nameB 0)]
                  )
                  ( application
                      (application (refLocal nameA 0) (refLocal nameA 1))
                      (application (refLocal nameB 0) (refLocal nameB 1))
                  )
              )

          nameA1 = Name $ nameToText nameA <> "1"
          nameB1 = Name $ nameToText nameB <> "1"

          renamed =
            lets
              ( Standalone (noAnn, nameA, valueA)
                  :| [Standalone (noAnn, nameB, valueB)]
              )
              ( lets
                  ( Standalone (noAnn, nameA1, refLocal nameA 0)
                      :| [Standalone (noAnn, nameB1, refLocal nameB 0)]
                  )
                  ( application
                      (application (refLocal nameA1 0) (refLocal nameA 0))
                      (application (refLocal nameB1 0) (refLocal nameB 0))
                  )
              )
      renameShadowedNamesInExpr mempty original === renamed

    -- Member order of a recursive group is the initialization order
    -- computed by the laziness transform; renaming must not disturb it.
    test "preserves member order of local recursive groups" do
      let x = Name "x"
          y = Name "y"
          original =
            lets
              ( RecursiveGroup
                  ( (noAnn, x, abstraction paramUnused (refLocal y 0))
                      :| [(noAnn, y, literalObject [(PropName "foo", refLocal x 0)])]
                  )
                  :| []
              )
              (refLocal y 0)
      renameShadowedNamesInExpr mempty original === original

    -- See Note [Sequential scoping of Let bindings]: a recursive group
    -- member's RHS sees every member of its own group, itself included,
    -- so renaming the binder must rename those references too.
    test "renames self-references inside a shadowing recursive group" do
      let x = Name "x"
          x1 = Name "x1"
          original =
            abstraction (paramNamed x) $
              lets
                ( RecursiveGroup
                    ((noAnn, x, application (exception "f") (refLocal x 0)) :| [])
                    :| []
                )
                (refLocal x 0)
          renamed =
            abstraction (paramNamed x) $
              lets
                ( RecursiveGroup
                    ((noAnn, x1, application (exception "f") (refLocal x1 0)) :| [])
                    :| []
                )
                (refLocal x1 0)
      renameShadowedNamesInExpr mempty original === renamed

    test "renames forward references inside a shadowing recursive group" do
      let x = Name "x"
          y = Name "y"
          x1 = Name "x1"
          original =
            abstraction (paramNamed x) $
              lets
                ( RecursiveGroup
                    ((noAnn, y, refLocal x 0) :| [(noAnn, x, literalInt 1)])
                    :| []
                )
                (application (refLocal y 0) (refLocal x 1))
          renamed =
            abstraction (paramNamed x) $
              lets
                ( RecursiveGroup
                    ((noAnn, y, refLocal x1 0) :| [(noAnn, x1, literalInt 1)])
                    :| []
                )
                (application (refLocal y 0) (refLocal x 0))
      renameShadowedNamesInExpr mempty original === renamed

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

wrapInModule ∷ Exp → Module
wrapInModule e =
  Module
    { moduleName = moduleNameFromString "Main"
    , moduleBindings = [Standalone (noAnn, Name "main", e)]
    , moduleImports = []
    , moduleExports = [Name "main"]
    , moduleReExports = Map.empty
    , moduleForeigns = []
    , modulePath = "Main.purs"
    }

let1 ∷ Name → Exp → Exp → Exp
let1 n e = lets (Standalone (noAnn, n, e) :| [])

isRef ∷ Exp → Bool
isRef = \case
  Ref {} → True
  _ → False
