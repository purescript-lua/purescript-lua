-- | A State-shaped hot loop: each iteration threads the state through
-- | two calls of a step returning a two-field Tuple, deconstructing
-- | each result immediately. The step body is deliberately over the
-- | call-site inline budget, and calling it twice keeps the use-once
-- | inliner away, so the per-call table can only disappear through the
-- | result-side worker/wrapper split returning the pair as Lua
-- | multiple values. Only the driver is exported: `step` is a
-- | module-internal helper, so once every call site binds the
-- | components directly nothing keeps a boxing wrapper alive and the
-- | artifact's per-call table allocations drop to zero.
module Bench.StateStep (run) where

import Prelude

import Data.Tuple (Tuple(..))

step :: Int -> Tuple Int Int
step s =
  let
    a1 = s + 1
    a2 = a1 + 3
    a3 = a2 - s
    a4 = a3 + a1
    a5 = a4 + 2
    a6 = a5 + a2
    a7 = a6 - a3
    a8 = a7 + a4
    a9 = a8 + 1
    a10 = a9 - a5
    a11 = a10 + a6
    a12 = a11 - a7
    a13 = a12 + a8
    a14 = a13 + a9
    a15 = a14 - a10
    a16 = a15 + a11
  in
    Tuple
      ((a1 + a3 + a5 + a7 + a9 + a11 + a13 + a15) `mod` 3)
      ((a2 + a4 + a6 + a8 + a10 + a12 + a14 + a16) `mod` 7)

run :: Int -> Int
run n = go 0 0 n
  where
  go :: Int -> Int -> Int -> Int
  go acc s i =
    if i <= 0 then acc
    else case step s of
      Tuple a s' -> case step s' of
        Tuple b s'' -> go (acc + a + b) s'' (i - 2)
