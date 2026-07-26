-- Building a record per element through Record.Unsafe surgery on a
-- manifest literal, read back across a function boundary. The map/foldl
-- pair keeps the built record live (the same anchoring as
-- Bench.CtorBuild), so folding the surgery can at best replace the
-- copy-per-step with a single literal build — one table allocation per
-- element instead of two.
module Bench.RecordSet where

import Prelude

import Data.Array (range)
import Data.Foldable (foldl)
import Record.Unsafe (unsafeGet, unsafeSet)

run :: Int -> Int
run n = foldl step 0 (map build (range 1 n))
  where
  build :: Int -> { a :: Int, b :: Int, c :: Int }
  build i = unsafeSet "c" (i + 2) { a: i, b: i + 1 }

  step :: Int -> { a :: Int, b :: Int, c :: Int } -> Int
  step acc r = acc + r.a + r.b + unsafeGet "c" r
