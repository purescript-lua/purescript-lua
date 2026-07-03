{- | First-class passes for the IR pipeline (issue #138).

A pass is a value carrying its contract: the invariants it requires of
its input and the invariants it ensures for its output. The pipeline is
a list of 'Step's interpreted by one of three runners:

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
-}
module Language.PureScript.Backend.IR.Pass
  ( Invariant (..)
  , Pass (..)
  , Step (..)
  , Phase (..)
  , PassCheckFailure (..)
  , runSteps
  , runStepsChecked
  , runStepsTraced
  , idempotently
  ) where

import Control.Monad.Error.Class (MonadError (throwError))
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule)
import Language.PureScript.Backend.IR.Linter (Violation, lintUberModule)
import Language.PureScript.Backend.IR.Supply (SupplyM)

--------------------------------------------------------------------------------
-- Passes and their contracts --------------------------------------------------

{- | A mechanically checkable property of the IR. Extended by the
globally-unique-names redesign (issue #139).
-}
data Invariant = WellScoped
  deriving stock (Eq, Ord, Show)

data Pass = Pass
  { passName ∷ Text
  , passRun ∷ UberModule → SupplyM UberModule
  , passRequires ∷ Set Invariant
  , passEnsures ∷ Set Invariant
  }

{- | One step of a pipeline: a single pass, or a sequence of passes
iterated until a whole-module 'Eq' fixpoint (same semantics as
'idempotently' over their composition).
-}
data Step
  = RunPass Pass
  | RunFixpoint Text (NonEmpty Pass)

data Phase = Before | After
  deriving stock (Eq, Show)

{- | A pass's contract did not hold: the named invariant set was violated
either on the pass's input ('Before') or on its output ('After').
-}
data PassCheckFailure = PassCheckFailure
  { failedPassName ∷ Text
  , failedPhase ∷ Phase
  , failedViolations ∷ NonEmpty Violation
  }
  deriving stock (Eq, Show)

--------------------------------------------------------------------------------
-- Runners ---------------------------------------------------------------------

runSteps ∷ [Step] → UberModule → SupplyM UberModule
runSteps steps uber0 = foldlM (flip runStep) uber0 steps
 where
  runStep ∷ Step → UberModule → SupplyM UberModule
  runStep = \case
    RunPass p → passRun p
    RunFixpoint _name passes →
      fixpointM \uber → foldlM (flip passRun) uber (toList passes)

runStepsChecked
  ∷ [Step] → UberModule → SupplyM (Either PassCheckFailure UberModule)
runStepsChecked steps uber0 = runExceptT (foldlM (flip runStep) uber0 steps)
 where
  runStep ∷ Step → UberModule → ExceptT PassCheckFailure SupplyM UberModule
  runStep = \case
    RunPass p → checkedPass p
    RunFixpoint _name passes →
      fixpointM \uber → foldlM (flip checkedPass) uber (toList passes)

  checkedPass
    ∷ Pass → UberModule → ExceptT PassCheckFailure SupplyM UberModule
  checkedPass Pass {passName, passRun, passRequires, passEnsures} uber = do
    check Before passRequires uber
    uber' ← lift (passRun uber)
    uber' <$ check After passEnsures uber'
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
  violations invariants u
    | WellScoped `Set.member` invariants = lintUberModule u
    | otherwise = []

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
    RunPass p → tracedPass (passName p) p
    RunFixpoint name passes → loop (1 ∷ Natural)
     where
      loop i uber = do
        uber' ←
          foldlM
            ( \u p →
                tracedPass (name <> "#" <> show i <> "/" <> passName p) p u
            )
            uber
            (toList passes)
        if uber' == uber then pure uber else loop (i + 1) uber'

  tracedPass
    ∷ Text
    → Pass
    → UberModule
    → StateT [(Text, UberModule)] SupplyM UberModule
  tracedPass label p uber = do
    uber' ← lift (passRun p uber)
    uber' <$ modify ((label, uber') :)

--------------------------------------------------------------------------------
-- Fixpoints -------------------------------------------------------------------

-- | Apply a function until it makes no change (by 'Eq').
idempotently ∷ Eq a ⇒ (a → a) → a → a
idempotently = fix $ \i f a →
  let a' = f a
   in if a' == a then a else i f a'

-- | Monadic 'idempotently'.
fixpointM ∷ (Monad m, Eq a) ⇒ (a → m a) → a → m a
fixpointM f = loop
 where
  loop a = do
    a' ← f a
    if a' == a then pure a else loop a'
