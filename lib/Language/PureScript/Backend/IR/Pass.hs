{- | First-class passes for the IR pipeline (issue #138).

A pass is a value carrying its contract: the invariants it requires of
its input, the invariants it ensures for its output, and a
'WasRewritten' signal on its result. The pipeline is a list of 'Step's
interpreted by one of three runners:

  * 'runSteps' — plain execution, no checking (the production default);
  * 'runStepsChecked' — lints 'passRequires' before and 'passEnsures'
    after every pass (including every pass of every fixpoint iteration),
    failing loudly with the offending pass's name. Used by the test
    suite and, behind a debug flag, by the CLI;
  * 'runStepsTraced' — like 'runSteps' but also records the module after
    each pass, for debugging.

'Step' exists (rather than a fixpoint /combinator/ returning an opaque
'Pass') so the checked runner can see through a fixpoint and lint each
iteration: a violation on an intermediate iteration that a later
iteration masks would otherwise be invisible.

A fixpoint iterates its passes until a whole round reports
'Unmodified', bounded by 'maxFixpointIterations' — no runner compares
whole modules for structural equality. The two ways the signal can be
imprecise are each caught in the direction that matters:

  * /under-reporting/ (changed the module, said it didn't) would stop a
    fixpoint early and silently under-optimize — the checked runner
    compares the one module a pass claims unchanged against its input
    and fails with 'PassUnreportedChange';
  * /over-reporting/ (said it changed, didn't) would spin a fixpoint
    forever — both runners stop at 'maxFixpointIterations', where the
    checked runner fails with 'FixpointDivergence' while the production
    runner accepts the module reached so far (every pass is
    semantics-preserving, so an early stop only costs optimization,
    never correctness).
-}
module Language.PureScript.Backend.IR.Pass
  ( Invariant (..)
  , Pass (..)
  , Step (..)
  , Phase (..)
  , PassCheckFailure (..)
  , renderPassCheckFailure
  , runSteps
  , runStepsChecked
  , runStepsTraced
  , idempotently
  , maxFixpointIterations
  ) where

import Control.Monad.Error.Class (MonadError (throwError))
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule)
import Language.PureScript.Backend.IR.Linter
  ( Violation
  , lintUniqueBinders
  , lintWellScoped
  )
import Language.PureScript.Backend.IR.Supply (SupplyM)
import Language.PureScript.Backend.IR.Types (WasRewritten (..))

--------------------------------------------------------------------------------
-- Passes and their contracts --------------------------------------------------

{- | A mechanically checkable property of the IR (issue #139):

  * 'WellScoped' — every local reference resolves to an enclosing binder;
  * 'UniqueBinders' — within one top-level site no local binder name is
    bound twice (the discard binder @_@ exempt).

'UniqueBinders' is the global-uniqueness condition (GUC): a local
reference resolves to its binder unambiguously by name.
-}
data Invariant = WellScoped | UniqueBinders
  deriving stock (Eq, Ord, Show)

data Pass = Pass
  { passName ∷ Text
  , passRun ∷ UberModule → SupplyM (UberModule, WasRewritten)
  {- ^ Run the pass. 'Unmodified' asserts the returned module is
  structurally identical to the input, 'Rewritten' says it may differ.
  Passes iterated by a 'RunFixpoint' must report precisely — the
  fixpoint stops on the first 'Unmodified' round — while a pass that
  only ever runs once may report a conservative 'Rewritten'.
  -}
  , passRequires ∷ Set Invariant
  , passEnsures ∷ Set Invariant
  }

{- | One step of a pipeline: a single pass, or a sequence of passes
iterated until a round reports no change (see 'passRun'), bounded by
'maxFixpointIterations'.
-}
data Step
  = RunPass Pass
  | RunFixpoint Text (NonEmpty Pass)

data Phase = Before | After
  deriving stock (Eq, Show)

-- | A pass broke its contract; thrown by 'runStepsChecked' only.
data PassCheckFailure
  = {- | The named pass violated the given invariant set either on its
    input ('Before') or on its output ('After').
    -}
    PassCheckFailure Text Phase (NonEmpty Violation)
  | {- | The named pass returned a module that differs from its input
    while reporting no change — the fixpoint oracle cannot trust it.
    -}
    PassUnreportedChange Text
  | {- | The named fixpoint did not converge within the given number of
    iterations ('maxFixpointIterations'): some pass over-reports
    changes or genuinely loops.
    -}
    FixpointDivergence Text Natural
  deriving stock (Eq, Show)

{- | The user-facing rendering of a contract violation (used by the CLI
behind @--lint-ir@).
-}
renderPassCheckFailure ∷ PassCheckFailure → Text
renderPassCheckFailure = \case
  PassCheckFailure failedPassName failedPhase failedViolations →
    unlines $
      [ "IR invariants violated "
          <> show failedPhase
          <> " optimizer pass "
          <> failedPassName
          <> ":"
      ]
        <> (show <$> toList failedViolations)
  PassUnreportedChange passName →
    "Optimizer pass "
      <> passName
      <> " changed the module while reporting no change."
  FixpointDivergence fixpointName iterations →
    "Optimizer fixpoint "
      <> fixpointName
      <> " did not converge within "
      <> show iterations
      <> " iterations."

{- | Iteration backstop for 'RunFixpoint'. Convergence normally takes a
handful of rounds, so this is far above anything legitimate: hitting it
means a pass over-reports changes or genuinely loops — a bug, which the
checked runner turns into a 'FixpointDivergence' while the production
runner accepts the (correct, possibly under-optimized) module reached.
-}
maxFixpointIterations ∷ Natural
maxFixpointIterations = 100

--------------------------------------------------------------------------------
-- Runners ---------------------------------------------------------------------

runSteps ∷ [Step] → UberModule → SupplyM UberModule
runSteps steps uber0 = foldlM (flip runStep) uber0 steps
 where
  runStep ∷ Step → UberModule → SupplyM UberModule
  runStep = \case
    RunPass p → fmap fst . passRun p
    RunFixpoint _name passes → loop maxFixpointIterations
     where
      loop ∷ Natural → UberModule → SupplyM UberModule
      loop 0 uber = pure uber -- cap reached: accept (see the module doc)
      loop n uber =
        runRound passRun uber (toList passes) >>= \case
          (uber', Rewritten) → loop (n - 1) uber'
          (uber', Unmodified) → pure uber'

runStepsChecked
  ∷ [Step] → UberModule → SupplyM (Either PassCheckFailure UberModule)
runStepsChecked steps uber0 = runExceptT (foldlM (flip runStep) uber0 steps)
 where
  runStep ∷ Step → UberModule → ExceptT PassCheckFailure SupplyM UberModule
  runStep = \case
    RunPass p → fmap fst . checkedPass p
    RunFixpoint name passes → loop maxFixpointIterations
     where
      loop
        ∷ Natural → UberModule → ExceptT PassCheckFailure SupplyM UberModule
      loop 0 _uber = throwError (FixpointDivergence name maxFixpointIterations)
      loop n uber =
        runRound checkedPass uber (toList passes) >>= \case
          (uber', Rewritten) → loop (n - 1) uber'
          (uber', Unmodified) → pure uber'

  checkedPass
    ∷ Pass
    → UberModule
    → ExceptT PassCheckFailure SupplyM (UberModule, WasRewritten)
  checkedPass Pass {passName, passRun, passRequires, passEnsures} uber = do
    check Before passRequires uber
    result@(uber', rewritten) ← lift (passRun uber)
    check After passEnsures uber'
    -- The under-reporting direction: 'Unmodified' must mean
    -- structurally identical output. This is the one surviving use of
    -- whole-module equality, paid only in the checked runner and only
    -- when a pass claims 'Unmodified'.
    when (rewritten == Unmodified && uber' /= uber) $
      throwError (PassUnreportedChange passName)
    pure result
   where
    check
      ∷ Phase
      → Set Invariant
      → UberModule
      → ExceptT PassCheckFailure SupplyM ()
    check phase invariants u =
      whenJust
        (nonEmpty (violations invariants u))
        (throwError . PassCheckFailure passName phase)

  violations ∷ Set Invariant → UberModule → [Violation]
  violations invariants u =
    foldMap
      ( \case
          WellScoped → lintWellScoped u
          UniqueBinders → lintUniqueBinders u
      )
      (Set.toList invariants)

{- | Like 'runSteps', but also record the module after each pass. Passes
run by a fixpoint are recorded per iteration as @fixpointName#N/passName@.
-}
runStepsTraced
  ∷ [Step] → UberModule → SupplyM (UberModule, [(Text, UberModule)])
runStepsTraced steps uber0 =
  second reverse <$> runStateT (foldlM (flip runStep) uber0 steps) []
 where
  -- The trace accumulates reversed (newest first) and is reversed once
  -- at the end.
  runStep ∷ Step → UberModule → StateT [(Text, UberModule)] SupplyM UberModule
  runStep = \case
    RunPass p → fmap fst . tracedPass (passName p) p
    RunFixpoint name passes → loop (1 ∷ Natural)
     where
      loop
        ∷ Natural
        → UberModule
        → StateT [(Text, UberModule)] SupplyM UberModule
      loop i uber = do
        (uber', rewritten) ←
          runRound
            (\p → tracedPass (name <> "#" <> show i <> "/" <> passName p) p)
            uber
            (toList passes)
        if rewritten == Rewritten && i < maxFixpointIterations
          then loop (i + 1) uber'
          else pure uber'

  tracedPass
    ∷ Text
    → Pass
    → UberModule
    → StateT [(Text, UberModule)] SupplyM (UberModule, WasRewritten)
  tracedPass label p uber = do
    result@(uber', _rewritten) ← lift (passRun p uber)
    result <$ modify ((label, uber') :)

-- | One fixpoint round: every pass once, 'WasRewritten' accumulated.
runRound
  ∷ Monad m
  ⇒ (Pass → UberModule → m (UberModule, WasRewritten))
  → UberModule
  → [Pass]
  → m (UberModule, WasRewritten)
runRound runPass uber0 =
  foldlM
    (\(uber, rewritten) p → second (rewritten <>) <$> runPass p uber)
    (uber0, mempty)

--------------------------------------------------------------------------------
-- Fixpoints -------------------------------------------------------------------

{- | Apply a function until it makes no change (by 'Eq') — the semantic
reference for what a 'WasRewritten'-driven 'RunFixpoint' computes when
its passes report precisely; the test suite checks the two against
each other.
-}
idempotently ∷ Eq a ⇒ (a → a) → a → a
idempotently = fix $ \i f a →
  let a' = f a
   in if a' == a then a else i f a'
