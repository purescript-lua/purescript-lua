-- A three-step Maybe bind chain; the benchmark driver applies `run` in a hot
-- loop, so each iteration goes through the Bind dictionary and constructor
-- allocation for every step.
module Bench.BindChain where

import Prelude

import Data.Maybe (Maybe(..), fromMaybe)

run :: Int -> Int
run x = fromMaybe 0 do
  a <- Just (x + 1)
  b <- Just (a + 1)
  Just (b + 1)
