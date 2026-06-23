module Golden.ArrayPatternMatch.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- Matching an array-literal pattern destructures by index. The binders must
-- read 1-based Lua slots; the regression in #49 read them 0-based, so the
-- first element came back nil and the match crashed at runtime.
firstTwo :: Array Int -> Int
firstTwo = case _ of
  [ a, b ] -> a + b
  _ -> -1

lastOfThree :: Array Int -> Int
lastOfThree = case _ of
  [ _, _, c ] -> c
  _ -> -1

main :: Effect Unit
main = do
  logShow (firstTwo [ 10, 20 ])
  logShow (firstTwo [ 1, 2, 3 ])
  logShow (firstTwo [])
  logShow (lastOfThree [ 7, 8, 9 ])
