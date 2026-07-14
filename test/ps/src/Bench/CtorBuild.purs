-- Building a data value in a hot loop. Every saturated constructor
-- application compiles to a curried closure chain, so each field past the
-- first allocates a closure (an FNEW under LuaJIT, which aborts the trace)
-- before the table is built. The map/foldl pair keeps the constructed values
-- live across a function boundary, so the case-of-known-constructor folds
-- cannot eliminate the allocation the way they do for an in-place match.
module Bench.CtorBuild where

import Prelude

import Data.Array (range)
import Data.Foldable (foldl)

data V = V Int Int Int

run :: Int -> Int
run n = foldl step 0 (map build (range 1 n))
  where
  build i = V i (i + 1) (i + 2)
  step acc (V a b c) = acc + a + b + c
