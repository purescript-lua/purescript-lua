-- | A hot ST loop accumulating through a non-escaping local `STRef`
-- | (issue #239). Boxed, every iteration pays the cell's field accesses
-- | plus a fresh `{state, value}` record from `modify`, and the cell
-- | itself is a heap table; unboxed, the loop is straight-line
-- | arithmetic on a plain Lua local with no table allocation at all.
module Bench.RefLoop where

import Prelude

import Control.Monad.ST as ST
import Control.Monad.ST.Ref as STRef

run :: Int -> Int
run n = ST.run do
  acc <- STRef.new 0
  ST.for 0 n \i -> void (STRef.modify (_ + i) acc)
  STRef.read acc
