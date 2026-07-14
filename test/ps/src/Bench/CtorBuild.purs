-- Building a data value in a hot loop. The map/foldl pair keeps the
-- constructed values live across a function boundary, so the
-- case-of-known-constructor folds cannot eliminate the construction the
-- way they do for an in-place match: each element genuinely builds a
-- data value through the constructor, making the loop an anchor for how
-- construction lowers to Lua.
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
