-- | Non-escaping Ref/STRef cells lower to plain mutable Lua locals
-- | (issue #239): `new` becomes a `local`, `read` the local itself,
-- | `write`/`modify` plain assignments — no `{value = …}` heap table.
-- |
-- | Covers the loop-accumulator shape (`sumTo`), a `modify'` whose
-- | state and value differ (`splitModify`), ST `write` returning the
-- | written value (`writeBack`), a cell that escapes by being stored
-- | inside another cell and therefore keeps its boxed form (`nested`),
-- | and an Effect `Ref` with direct `read`/`write` (`main`).
module Golden.RefUnbox.Test where

import Prelude

import Control.Monad.ST (for, run)
import Control.Monad.ST.Ref as STRef
import Effect (Effect)
import Effect.Console (logShow)
import Effect.Ref as Ref

-- | Fully unboxable: allocate, mutate in a loop, read once at the end.
sumTo :: Int -> Int
sumTo n = run do
  acc <- STRef.new 0
  for 0 (n + 1) \i -> STRef.modify (_ + i) acc
  STRef.read acc

-- | `modify'` with distinct state and value components.
splitModify :: Int -> Int
splitModify n = run do
  r <- STRef.new n
  v <- STRef.modify' (\s -> { state: s * 2, value: s + 100 }) r
  s <- STRef.read r
  pure (v + s)

-- | ST `write` returns the written value.
writeBack :: Int
writeBack = run do
  r <- STRef.new 1
  x <- STRef.write 7 r
  y <- STRef.read r
  pure (x + y)

-- | The inner cell is stored in the outer cell — used as a whole value —
-- | so it keeps its `{value = …}` table; the outer cell still unboxes.
nested :: Int
nested = run do
  inner <- STRef.new 21
  outer <- STRef.new inner
  cell <- STRef.read outer
  _ <- STRef.modify (_ * 2) cell
  STRef.read cell

main :: Effect Unit
main = do
  logShow (sumTo 10)
  logShow (splitModify 3)
  logShow writeBack
  logShow nested
  counter <- Ref.new 10
  v <- Ref.read counter
  Ref.write (v + 1) counter
  w <- Ref.read counter
  logShow w
