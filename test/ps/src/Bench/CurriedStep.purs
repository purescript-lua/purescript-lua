-- | A hot loop through a two-argument function that is always fully
-- | applied — the shape the uncurrying worker/wrapper split turns into
-- | a direct n-ary call, which is what lets LuaJIT record a trace
-- | through it instead of aborting on per-iteration closure creation.
module Bench.CurriedStep where

import Prelude

run :: Int -> Int
run n = go 0 n
  where
  go :: Int -> Int -> Int
  go acc i = if i == 0 then acc else go (acc + i) (i - 1)
