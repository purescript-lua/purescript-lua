-- | Exercises the late uncurry run (issue #200): saturated spines that
-- | only exist once magicDo has rewritten do-blocks into explicit
-- | thunk-forcing. A unary effect action sits below the split threshold
-- | before magicDo (manifest arity 1) and above it after (λn.λ_), so
-- | only the late run can split it — absorbing the thunk parameter into
-- | the worker, which turns every statement call `tick(n)()` into the
-- | single call `tick$w(n)`. The eval oracle pins runtime behavior.
module Golden.UncurryEffect.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log, logShow)

-- Manifest arity 1 before magicDo — never an early-run candidate —
-- and 2 after. Statement sites absorb the effect-run marker into a
-- direct worker call.
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
