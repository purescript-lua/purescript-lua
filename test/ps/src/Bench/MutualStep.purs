-- | The mutual twin of `Bench.CurriedStep`: the same hot two-argument
-- | accumulator loop, but split across two workers tail-calling each
-- | other, so every iteration is a transition between group members.
-- | Dispatched (issue #234), the pair becomes one `while true` loop
-- | over a branch selector — a stable loop trace instead of a CALL/RET
-- | per transition.
module Bench.MutualStep where

import Prelude

run :: Int -> Int
run n = stepA 0 n
  where
  stepA :: Int -> Int -> Int
  stepA acc i = if i == 0 then acc else stepB (acc + i) (i - 1)

  stepB :: Int -> Int -> Int
  stepB acc i = if i == 0 then acc else stepA (acc + i) (i - 1)
