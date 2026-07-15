-- | A fold-shaped hot loop carrying a `Tuple` accumulator — the shape
-- | call-pattern specialization (issue #208) unboxes: without it every
-- | iteration builds a fresh two-field table only for the next
-- | iteration's match to take it apart; with it the loop carries the
-- | two fields as raw parameters and the box materializes only on the
-- | exit path.
module Bench.TupleFold where

import Prelude

import Data.Tuple (Tuple(..))

run :: Int -> Int
run n = case go (Tuple 0 0) of
  Tuple s _ -> s
  where
  go :: Tuple Int Int -> Tuple Int Int
  go acc = case acc of
    Tuple s i
      | i >= n -> acc
      | otherwise -> go (Tuple (s + i) (i + 1))
