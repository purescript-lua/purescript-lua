-- | Exercises loopification (issue #181): a self-recursive tail call of
-- | an uncurried worker lowers to a `while true` loop with parameter
-- | reassignment. The eval oracle pins that every shape keeps its
-- | runtime behavior, loopified or not.
module Golden.Loopification.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- Unary self-recursion: no worker/wrapper split happens (manifest arity
-- is 1), yet the binding itself is its own "worker" and loopifies.
countdown :: Int -> Int
countdown n = if n <= 0 then 0 else countdown (n - 1)

-- The canonical accumulator loop: the binary worker loopifies, and the
-- multiple assignment swaps both parameters simultaneously.
sumTo :: Int -> Int -> Int
sumTo acc n = if n == 0 then acc else sumTo (acc + n) (n - 1)

-- A local recursive worker: `local go` inside the enclosing function
-- loopifies the same way the top-level ones do.
sumSquares :: Int -> Int
sumSquares m = go 0 m
  where
  go :: Int -> Int -> Int
  go acc n = if n == 0 then acc else go (acc + n * n) (n - 1)

-- McCarthy 91: the outer self-call is a tail call and becomes a loop
-- iteration; the inner one is an argument and stays a real recursive
-- call.
mc91 :: Int -> Int
mc91 n = if n > 100 then n - 10 else mc91 (mc91 (n + 11))

-- The continuation accumulates closures over the loop-carried
-- parameters. Reassigning those parameters would corrupt the captured
-- environments, so this binding must not loopify.
sumCPS :: Int -> (Int -> Int) -> Int
sumCPS n k = if n == 0 then k 0 else sumCPS (n - 1) (\r -> k (r + n))

-- The second parameter is dead: it is dropped from the worker while the
-- recursive call still passes a value in its position, so the loop
-- assignment has more values than variables and discards the surplus.
countDrop :: Int -> Int -> Int
countDrop n _ = if n == 0 then 0 else countDrop (n - 1) n

main :: Effect Unit
main = do
  logShow (countdown 5)
  logShow (sumTo 0 10)
  logShow (sumSquares 4)
  logShow (mc91 1)
  logShow (sumCPS 5 identity)
  logShow (countDrop 3 99)
