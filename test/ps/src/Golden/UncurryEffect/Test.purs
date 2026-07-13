-- | Exercises the late uncurry run (issue #200): saturated spines that
-- | only exist once magicDo has rewritten do-blocks into explicit
-- | thunk-forcing. A unary effect action sits below the split threshold
-- | before magicDo (manifest arity 1) and above it after (λn.λ_), so
-- | only the late run can split it, absorbing the thunk parameter into
-- | the worker. `countdown` demonstrates the split — recursive bindings
-- | are never inlined, so its statement sites become the single call
-- | `countdown$w(n)` instead of `countdown(n)()`. `tick` pins the other
-- | legitimate outcome for a small non-recursive action: the specialize
-- | pass pastes its body into the saturated statement sites before the
-- | late run sees them, eliminating those calls altogether (the binding
-- | survives as an export, still curried). The eval oracle pins runtime
-- | behavior.
module Golden.UncurryEffect.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log, logShow)

-- Manifest arity 1 before magicDo, so never an early-run candidate.
-- Its body is under the call-site inline budget: the specialize pass
-- pastes it into the statement sites before the late run can split it,
-- so no worker appears and the executed statements are the pasted
-- bodies. The exported binding itself stays curried.
tick :: Int -> Effect Unit
tick n = do
  log "tick"
  logShow n

-- A recursive driver: the entry call becomes a direct worker call. The
-- self-call sits under the trailing `if` — the run applies to the if's
-- result — so it stays partial and keeps going through the wrapper.
countdown :: Int -> Effect Unit
countdown n = do
  tick n
  if n <= 1
    then log "done"
    else countdown (n - 1)

-- Actions received as values are locals, not candidates: their
-- statement calls keep the curried call-then-force shape, and the
-- arguments passed below stay references to the curried wrappers.
runBoth :: (Int -> Effect Unit) -> Effect Unit
runBoth act = do
  act 1
  act 2

main :: Effect Unit
main = do
  tick 7
  countdown 3
  runBoth tick
  runBoth countdown
