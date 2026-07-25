-- | Exercises loopification of mutual recursion (issue #234): a group
-- | of workers whose members tail-call each other lowers to a single
-- | `while true` dispatcher over a branch selector plus shared argument
-- | slots, with per-member entry wrappers. The eval oracle pins that
-- | every shape keeps its runtime behavior, dispatched or not.
module Golden.MutualLoopification.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- The canonical mutual pair: manifest arity 1, so no worker/wrapper
-- split happens and the bindings themselves form the dispatched group.
isEven :: Int -> Boolean
isEven n = if n == 0 then true else isOdd (n - 1)

isOdd :: Int -> Boolean
isOdd n = if n == 0 then false else isEven (n - 1)

-- Differing arities: the shared slots take the maximum width, and the
-- narrower member's transitions pad the surplus slots.
zigzag :: Int -> Int -> Int
zigzag acc n = if n == 0 then acc else zag acc n 1

zag :: Int -> Int -> Int -> Int
zag acc n d = if n == 0 then acc else zigzag (acc + d) (n - 1)

-- A three-state machine: the dispatcher carries more than two branches.
red :: Int -> Int -> Int
red acc n = if n == 0 then acc else green (acc + 1) (n - 1)

green :: Int -> Int -> Int
green acc n = if n == 0 then acc else blue (acc + 1) (n - 1)

blue :: Int -> Int -> Int
blue acc n = if n == 0 then acc else red (acc + 1) (n - 1)

-- Mixed self- and sibling-tail-calls in one member: both become
-- selector transitions of the same dispatcher.
stepSelf :: Int -> Int -> Int
stepSelf acc n =
  if n == 0 then acc
  else if n > 10 then stepSelf (acc + 10) (n - 10)
  else stepOther acc n

stepOther :: Int -> Int -> Int
stepOther acc n = if n == 0 then acc else stepSelf (acc + 1) (n - 1)

-- Non-tail mutual recursion: the sibling call is an operand, so the
-- group must keep real calls.
treeA :: Int -> Int
treeA n = if n == 0 then 1 else 1 + treeB (n - 1)

treeB :: Int -> Int
treeB n = if n == 0 then 2 else 2 + treeA (n - 1)

-- A let-bound mutual pair: the dispatcher and its wrappers are locals
-- of the enclosing function.
ticktock :: Int -> Int
ticktock n = tick 0 n
  where
  tick :: Int -> Int -> Int
  tick acc k = if k == 0 then acc else tock (acc + 1) (k - 1)

  tock :: Int -> Int -> Int
  tock acc k = if k == 0 then acc else tick (acc + 3) (k - 1)

main :: Effect Unit
main = do
  logShow (isEven 10)
  logShow (isOdd 7)
  logShow (zigzag 0 3)
  logShow (red 0 10)
  logShow (stepSelf 0 25)
  logShow (treeA 5)
  logShow (ticktock 5)
