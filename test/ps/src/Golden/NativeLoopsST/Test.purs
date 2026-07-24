-- | ST twins of the Effect loop combinators (issue #233):
-- | `Control.Monad.ST.Internal.for`/`foreach`/`while` lower to the same
-- | native Lua loops as their Effect counterparts, inside `ST.run`.
module Golden.NativeLoopsST.Test where

import Prelude

import Control.Monad.ST (for, foreach, run, while)
import Control.Monad.ST.Ref as STRef
import Effect (Effect)
import Effect.Console (logShow)

sumTo :: Int -> Int
sumTo n = run do
  acc <- STRef.new 0
  for 0 (n + 1) \i -> STRef.modify (_ + i) acc
  STRef.read acc

sumArray :: Array Int -> Int
sumArray xs = run do
  acc <- STRef.new 0
  foreach xs \x -> void (STRef.modify (_ + x) acc)
  STRef.read acc

countDown :: Int -> Int
countDown start = run do
  steps <- STRef.new 0
  value <- STRef.new start
  while (map (_ > 0) (STRef.read value)) do
    _ <- STRef.modify (_ - 1) value
    STRef.modify (_ + 1) steps
  STRef.read steps

main :: Effect Unit
main = do
  logShow (sumTo 10)
  logShow (sumArray [ 1, 2, 3, 4 ])
  logShow (countDown 5)
