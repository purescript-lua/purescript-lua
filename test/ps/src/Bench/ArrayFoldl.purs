-- Foldable `foldl` over an Array with a curried step function. The FFI fold
-- loop is a plain Lua `for`, but every step application is a curried call
-- chain, so a tracing JIT has to inline closure creation to compile the loop.
module Bench.ArrayFoldl where

import Prelude

import Data.Array (range)
import Data.Foldable (foldl)

run :: Int -> Int
run n = foldl (\acc i -> acc + i) 0 (range 1 n)
