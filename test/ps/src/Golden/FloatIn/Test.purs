module Golden.FloatIn.Test where

import Prelude
import Effect (Effect)
import Effect.Console (logShow)

expensive :: Int -> Int
expensive x = x * x + 1

pick :: Boolean -> Int -> Int
pick useIt n =
  let
    shared = expensive n
  in
    if useIt then shared + shared else 0

main :: Effect Unit
main = do
  logShow (pick true 3)
  logShow (pick false 3)
