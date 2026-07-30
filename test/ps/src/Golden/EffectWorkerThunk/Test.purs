-- | Exercises absorbing the magic-do thunk into an early-split effect
-- | worker (issue #265). An effect action of two or more real arguments
-- | is saturated before magic-do runs, so the uncurry split fires at the
-- | real arity and the worker's body is later rewritten into a thunk:
-- | every statement site then reads `f$w(a, b)()`, one closure and one
-- | extra call. `report` shows the plain win (its wrapper is dead, so
-- | only the worker survives). `tally` is also passed as a value, so its
-- | curried wrapper stays alive and must grow a parameter to keep a
-- | partial application evaluating to a closure. `deferred` pins the
-- | disqualified shape: its worker call is bound as an action value and
-- | run later, a site that extending the arity would leave
-- | under-applied, so the binding keeps the call-then-force shape.
module Golden.EffectWorkerThunk.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log, logShow)

report :: String -> Int -> Effect Unit
report tag n = do
  log tag
  logShow n
  log "-"

tally :: String -> Int -> Effect Unit
tally tag n = do
  log tag
  logShow (n * 2)
  log "="

deferred :: String -> Int -> Effect Unit
deferred tag n = do
  log tag
  logShow (n + 100)
  log "+"

runWith :: (String -> Int -> Effect Unit) -> Effect Unit
runWith f = do
  f "via" 3
  log "ran"

main :: Effect Unit
main = do
  report "a" 1
  report "b" 2
  tally "c" 3
  runWith tally
  let step a b = do
        log a
        logShow (b * 10)
        log "*"
  step "e" 5
  step "f" 6
  let held = deferred "d" 4
  log "before held"
  held
  held
