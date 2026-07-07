-- | Exercises the worker/wrapper uncurrying pass end to end: functions
-- | used saturated, partially applied, passed higher-order, mutually
-- | recursive, locally recursive, over-applied, and with an unused
-- | parameter. The eval oracle pins that the transformation preserves
-- | runtime behavior for every shape.
module Golden.Uncurry.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- Used saturated, partially applied, and passed higher-order: the
-- saturated sites go through the worker while the curried wrapper
-- keeps serving the other two shapes.
add3 :: Int -> Int -> Int -> Int
add3 x y z = x + y + z

-- A top-level partial application of `add3` (a value binding).
inc :: Int -> Int
inc = add3 1 0

-- Mutually recursive, both always saturated: the recursive calls
-- should become direct worker-to-worker calls.
evenSteps :: Int -> Int -> Int
evenSteps acc n = if n == 0 then acc else oddSteps (acc + 1) (n - 1)

oddSteps :: Int -> Int -> Int
oddSteps acc n = if n == 0 then acc else evenSteps (acc + 1) (n - 1)

-- A local recursive two-argument loop.
sumTo :: Int -> Int
sumTo m = go 0 m
  where
  go :: Int -> Int -> Int
  go acc n = if n == 0 then acc else go (acc + n) (n - 1)

-- Returns a function: `adderOf a b c` over-applies the manifest arity.
adderOf :: Int -> Int -> (Int -> Int)
adderOf x y = add (x + y)

-- An unused second parameter.
alwaysFirst :: Int -> Int -> Int
alwaysFirst x _ = x

main :: Effect Unit
main = do
  logShow (add3 1 2 3)
  logShow (add3 4 5 6)
  let f = add3 10
  logShow (f 1 2)
  logShow (inc 41)
  logShow (map (add3 1 2) [ 1, 2, 3 ])
  logShow (evenSteps 0 10)
  logShow (oddSteps 0 7)
  logShow (sumTo 10)
  logShow (sumTo 100)
  logShow (adderOf 1 2 3)
  logShow (adderOf 2 3 4)
  logShow (alwaysFirst 7 8)
  logShow (alwaysFirst 9 10)
