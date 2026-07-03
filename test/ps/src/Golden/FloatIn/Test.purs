module Golden.FloatIn.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- Prints "tick" every time it is evaluated, so the eval oracle observes
-- how many times (and on which branch) the float-in pass lets a binding
-- run: once inside the taken branch, never on the branch not taken, and
-- never once per call of a lambda that closes over it (the #136 bug).
foreign import tick :: Int -> Int

expensive :: Int -> Int
expensive x = x * x + 1

pick :: Boolean -> Int -> Int
pick useIt n =
  let
    shared = expensive n
  in
    if useIt then shared + shared else 0

-- `shared` is used only inside `f`, and `f` only in the then-branch:
-- float-in must land `shared` inside the branch but above the lambda,
-- so `tick` prints once however many times `f` is called.
pickShared :: Boolean -> Int -> Int
pickShared useIt n =
  let
    shared = tick n
    f = \_ -> shared + shared
  in
    if useIt then f unit + f unit else 0

main :: Effect Unit
main = do
  logShow (pick true 3)
  logShow (pick false 3)
  logShow (pickShared true 3)
  logShow (pickShared false 3)
