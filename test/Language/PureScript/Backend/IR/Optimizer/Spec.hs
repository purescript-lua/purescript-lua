module Language.PureScript.Backend.IR.Optimizer.Spec where

import Data.Map qualified as Map
import Hedgehog (PropertyT, annotateShow, diff, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Inliner (Annotation (Never))
import Language.PureScript.Backend.IR.Linker (LinkMode (..))
import Language.PureScript.Backend.IR.Linker qualified as Linker
import Language.PureScript.Backend.IR.Linter
  ( lintUniqueBinders
  , lintWellScoped
  , unboundLocals
  )
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
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , Module (..)
  , RawExp (..)
  , abstraction
  , alphaEq
  , application
  , countFreeRef
  , eq
  , ifThenElse
  , isLiteral
  , lets
  , literalBool
  , literalInt
  , literalObject
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  )
import Test.Hspec (Spec, SpecWith, describe, it, shouldBe)
import Test.Hspec.Hedgehog (hedgehog, modifyMaxShrinks, modifyMaxSuccess)
import Test.Hspec.Hedgehog.Extended (test)

-- | Like 'test', but runs the property over many generated inputs.
prop ∷ String → PropertyT IO () → SpecWith ()
prop title =
  modifyMaxShrinks (const 20)
    . modifyMaxSuccess (const 100)
    . it title
    . hedgehog

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

    test "removes if with alpha-equal branches" do
      -- The branches differ only in binder names, so the condition
      -- cannot influence the result.
      cond ← forAll Gen.name
      let branch param = abstraction (paramNamed param) (refLocal param)
          original =
            ifThenElse
              (refLocal cond)
              (branch (Name "x"))
              (branch (Name "y"))
      optimizedExpression original === branch (Name "x")

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
              (refImported dict (Name "eqList"))
              (refImported dict (Name "eqInt"))
          original = abstraction (paramNamed param) (application m (refLocal param))
      optimizedExpression original === original

  describe "inlines expressions" do
    test "inlines literals" do
      name ← forAll Gen.name
      inlinee ← forAll Gen.scalarExp
      let original = let1 name inlinee (refLocal name)
          expected = let1 name inlinee inlinee
      optimizedExpression original === expected

    test "inlines references" do
      name ← forAll Gen.name
      -- A reference to the binding's own name is the one reference that
      -- must NOT be inlined (see the self-inlining test below), so the
      -- inlinee is drawn from the other names.
      inlinee ← refLocal <$> forAll (mfilter (/= name) Gen.name)
      let original = let1 name inlinee (refLocal name)
          expected = let1 name inlinee inlinee
      optimizedExpression original === expected

    -- Regression: substituting @x := x@ is a textual no-op, so the
    -- occurrence count of @x@ never reaches zero and an unguarded rule
    -- keeps firing forever under the driver's repeat-until-Nothing
    -- (caught by CI hanging: the generator above draws the same name
    -- for binder and inlinee with probability 1/7). Such input is
    -- outside the pipeline's GUC domain — under unique binders a
    -- Standalone RHS cannot see its own binder — so the rule must
    -- decline, not loop.
    it "declines to inline a self-referential binding" do
      let x = Name "x"
          original = let1 x (refLocal x) (refLocal x)
      optimizedExpression original `shouldBe` original

    test "inlines expressions referenced once" do
      name ← forAll Gen.name
      inlinee ← forAll $ fmap optimizedExpression do
        -- No self-reference: inlining a binding whose RHS mentions its
        -- own name is declined by the optimizer (non-GUC input).
        mfilter
          ( \e →
              not (isRef e || isLiteral e)
                && countFreeRef (Local name) e == 0
          )
          Gen.exp
      let body = refLocal name
          original = let1 name inlinee body
          expected = let1 name inlinee inlinee
      annotateShow body
      -- The inserted copy gets fresh binder names ('substituteCopyM'
      -- freshens every insertion), so compare up to alpha-equivalence.
      diff (optimizedExpression original) alphaEq expected

    test "doesn't inline expressions referenced more than once" do
      name ← forAll Gen.name
      inlinee ← forAll $ Gen.choice [Gen.exception, Gen.ctor]
      let original =
            let1 name inlinee $
              application (refLocal name) (refLocal name)
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
                  [(Name "main", refImported mainModule (Name "foo"))]
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
                  (eq (refLocal name) (literalInt 42))
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
                        (refImported dict (Name "bind"))
                        (refLocal (Name "fn1"))
                    )
                    :| [ Standalone
                           ( noAnn
                           , Name "discard1"
                           , application
                               (refImported dict (Name "discard"))
                               (refLocal (Name "Bind1"))
                           )
                       ]
                )
                ( application
                    (refLocal (Name "discard1"))
                    (refLocal (Name "discard1"))
                )
          barExp =
            abstraction (paramNamed (Name "f")) $
              lets
                ( Standalone
                    ( noAnn
                    , Name "Bind1"
                    , application
                        (refImported dict (Name "bind"))
                        (refLocal (Name "f"))
                    )
                    :| []
                )
                ( application
                    ( application
                        (refImported mainModule (Name "foo"))
                        (refLocal (Name "f"))
                    )
                    ( application
                        (refLocal (Name "Bind1"))
                        (refLocal (Name "Bind1"))
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
                        (refImported mainModule (Name "bar"))
                        (literalInt 7)
                    )
                  ]
              }
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []

    -- Issue #56: `b` is bound by an outer λ while the reduced inner λ is
    -- \*also* named `b`; reducing the redexes must leave the surviving
    -- reference bound to the outer binder. This is the IR shape
    -- `Data.Array.foldRecM` boils down to.
    test "beta reduction does not unbind a reference shadowed by the binder" do
      let a = Name "a"
          b = Name "b"
          inner =
            abstraction (paramNamed a) $
              abstraction (paramNamed b) $
                literalObject
                  [ (PropName "p", refLocal a)
                  , (PropName "q", refLocal b)
                  ]
          -- (\b -> (\a -> \b -> { p: a, q: b }) b 0)
          shadowed =
            abstraction (paramNamed b) $
              application
                (application inner (refLocal b))
                (literalInt 0)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "foldRecMShape", shadowed)]
              }
          -- After the redexes are reduced only the outer λ remains, so the
          -- surviving reference is the outer `b`.
          expected =
            abstraction (paramNamed b) $
              literalObject
                [ (PropName "p", refLocal b)
                , (PropName "q", literalInt 0)
                ]
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []
      Linker.uberModuleExports optimized === [(Name "foldRecMShape", expected)]

    -- Sibling of #56 in the DCE pass (found by the property below).
    -- Dead-code elimination blanks the unused inner λj to ParamUnused;
    -- every reference to the outer j must stay bound to it.
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
                                abstraction (paramNamed j) (refLocal k)
                            )
                            (literalInt 0)
                        )
                      ]
                )
                (refLocal j)
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
      lintWellScoped optimized === []
      -- The full pipeline ends GUC-clean, not merely well-scoped:
      lintUniqueBinders optimized === []

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
