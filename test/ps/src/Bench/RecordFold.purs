-- | A fold whose step builds a record, updates it, and reads the
-- | result back field-wise — never passing either table on whole
-- | (issue #240). Boxed, every element allocates the literal plus the
-- | update's runtime copy; unpacked, the step is straight-line
-- | arithmetic with no table allocation at all.
module Bench.RecordFold where

import Prelude

import Data.Array (range)
import Data.Foldable (foldl)

run :: Int -> Int
run n = foldl step 0 (range 1 n)
  where
  step :: Int -> Int -> Int
  step acc i =
    let
      r = { lo: i, hi: i + 1 }
      s = r { hi = r.hi * 2 }
    in
      acc + s.lo + s.hi
