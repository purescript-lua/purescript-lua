module Language.PureScript.Backend.IR.Pass.Spec where

import Data.Set qualified as Set
import Hedgehog (PropertyT, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter (Site (..), Violation (..))
import Language.PureScript.Backend.IR.Names (Name (..))
import Language.PureScript.Backend.IR.Pass
  ( Invariant (..)
  , Pass (..)
  , PassCheckFailure (..)
  , Phase (..)
  , Step (..)
  , idempotently
  , renderPassCheckFailure
  , runSteps
  , runStepsChecked
  )
import Language.PureScript.Backend.IR.Supply (runSupply)
import Language.PureScript.Backend.IR.Types
  ( Exp
  , RawExp (..)
  , abstraction
  , literalInt
  , paramNamed
  , refLocal
  )
import Test.Hspec (Spec, SpecWith, describe, it, shouldBe)
import Test.Hspec.Hedgehog (hedgehog, modifyMaxSuccess)

{- | Like 'Test.Hspec.Hedgehog.Extended.test', but runs the property over
many generated inputs.
-}
prop ∷ String → PropertyT IO () → SpecWith ()
prop title = modifyMaxSuccess (const 100) . it title . hedgehog

spec ∷ Spec
spec = describe "IR Pass runner" do
  it "checked runner reports the pass that broke an invariant" do
    let breakScope = purePass "break-scope" (constExports unboundRef)
    runSupply (runStepsChecked [RunPass breakScope] (exporting (literalInt 0)))
      `shouldBe` Left
        PassCheckFailure
          { failedPassName = "break-scope"
          , failedPhase = After
          , failedViolations = pure (UnboundLocal (InExport main) y)
          }

  it "checked runner reports a violated precondition" do
    let keep = purePass "keep" id
    runSupply (runStepsChecked [RunPass keep] (exporting unboundRef))
      `shouldBe` Left
        PassCheckFailure
          { failedPassName = "keep"
          , failedPhase = Before
          , failedViolations = pure (UnboundLocal (InExport main) y)
          }

  it "checked runner sees intermediate fixpoint iterations" do
    -- First iteration breaks scoping, second heals it and converges: the
    -- final module is clean, so only per-iteration linting can catch it.
    let step ∷ UberModule → UberModule
        step uber = case uberModuleExports uber of
          [(_name, LiteralInt _ 0)] → constExports unboundRef uber
          [(_name, Ref {})] → constExports (literalInt 1) uber
          _ → uber
        fixpoint = RunFixpoint "toggle" (pure (purePass "step" step))
        start = exporting (literalInt 0)
    -- The unchecked runner happily converges on the healed module…
    runSupply (runSteps [fixpoint] start)
      `shouldBe` exporting (literalInt 1)
    -- …the checked runner fails on the intermediate iteration.
    runSupply (runStepsChecked [fixpoint] start)
      `shouldBe` Left
        PassCheckFailure
          { failedPassName = "step"
          , failedPhase = After
          , failedViolations = pure (UnboundLocal (InExport main) y)
          }

  it "checked runner lints exactly the declared invariants" do
    -- λx. λx. x is well-scoped, but breaks UniqueBinders (shadowing).
    let x = Name "x"
        shadowing =
          abstraction
            (paramNamed x)
            (abstraction (paramNamed x) (refLocal x))
        produce invariants =
          Pass
            { passName = "produce"
            , passRun = pure . constExports shadowing
            , passRequires = Set.singleton WellScoped
            , passEnsures = invariants
            }
        run invariants =
          runSupply
            ( runStepsChecked
                [RunPass (produce invariants)]
                (exporting (literalInt 0))
            )
    -- A pass that only promises well-scopedness passes the check…
    run (Set.singleton WellScoped)
      `shouldBe` Right (exporting shadowing)
    -- …while promising the GUC invariant dispatches its linter.
    run (Set.fromList [WellScoped, UniqueBinders])
      `shouldBe` Left
        PassCheckFailure
          { failedPassName = "produce"
          , failedPhase = After
          , failedViolations = pure (DuplicateBinder (InExport main) x)
          }

  it "renders a check failure for the CLI (--lint-ir)" do
    -- The exact wording is user-facing: the CLI dies with this text.
    renderPassCheckFailure
      PassCheckFailure
        { failedPassName = "break-scope"
        , failedPhase = After
        , failedViolations =
            UnboundLocal (InExport main) y
              :| [DuplicateBinder (InExport main) y]
        }
      `shouldBe` unlines
        [ "IR invariants violated After optimizer pass break-scope:"
        , "UnboundLocal (InExport (Name \"main\")) (Name \"y\")"
        , "DuplicateBinder (InExport (Name \"main\")) (Name \"y\")"
        ]

  prop "fixpoint has 'idempotently' semantics" do
    limit ← forAll $ Gen.integral (Range.linear 0 20)
    start ← forAll $ Gen.integral (Range.linear 0 25)
    let f ∷ UberModule → UberModule
        f uber = case uberModuleExports uber of
          [(_name, LiteralInt _ n)] | n < limit → exporting (literalInt (n + 1))
          _ → uber
    runSupply
      ( runSteps
          [RunFixpoint "f" (pure (purePass "f" f))]
          (exporting (literalInt start))
      )
      === idempotently f (exporting (literalInt start))

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

main ∷ Name
main = Name "main"

y ∷ Name
y = Name "y"

unboundRef ∷ Exp
unboundRef = refLocal y

exporting ∷ Exp → UberModule
exporting e =
  UberModule
    { uberModuleBindings = []
    , uberModuleForeigns = []
    , uberModuleExports = [(main, e)]
    }

constExports ∷ Exp → UberModule → UberModule
constExports e uber =
  uber
    { uberModuleExports =
        [(name, e) | (name, _prev) ← uberModuleExports uber]
    }

purePass ∷ Text → (UberModule → UberModule) → Pass
purePass name run =
  Pass
    { passName = name
    , passRun = pure . run
    , passRequires = Set.singleton WellScoped
    , passEnsures = Set.singleton WellScoped
    }
