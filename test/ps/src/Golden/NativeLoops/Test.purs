-- | Effect loop combinators lowered to native Lua loops (issue #233):
-- | `forE` becomes a numeric `for` over the half-open range, `foreachE`
-- | an indexed `for` over the array, `whileE` a `while` running the
-- | condition thunk each iteration. Covers a literal-lambda body
-- | (inlined as the loop body), a non-literal body function (pre-bound
-- | and called per element), a loop in tail position, and a nested loop.
module Golden.NativeLoops.Test where

import Prelude

import Effect (Effect, forE, foreachE, whileE)
import Effect.Console (log, logShow)
import Effect.Ref as Ref

main :: Effect Unit
main = do
  log "forE:"
  forE 1 4 logShow
  log "foreachE:"
  sum <- Ref.new 0
  foreachE [ 10, 20, 30 ] \n -> Ref.modify_ (_ + n) sum
  total <- Ref.read sum
  logShow total
  log "whileE:"
  counter <- Ref.new 0
  whileE (map (_ < 3) (Ref.read counter)) do
    n <- Ref.read counter
    logShow n
    Ref.modify_ (_ + 1) counter
  log "nested:"
  forE 0 2 \i ->
    foreachE [ "x", "y" ] \s ->
      log (show i <> s)
