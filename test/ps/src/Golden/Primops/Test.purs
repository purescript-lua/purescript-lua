module Golden.Primops.Test where

import Prelude
import Effect (Effect)
import Effect.Console (log, logShow)

-- Recursive, so the lifted arithmetic and comparison primops survive as
-- Lua operators over the variables `acc` and `n` (they cannot fold to a
-- constant), exercising the non-literal path of the lift.
sumTo :: Int -> Int -> Int
sumTo acc n = if n <= 0 then acc else sumTo (acc + n) (n - 1)

main :: Effect Unit
main = do
  logShow (sumTo 0 5) -- 15
  logShow (7 >= 3) -- true
  logShow (3 == (3 :: Int)) -- true
  logShow (compare 2 (5 :: Int)) -- LT
  log ("foo" <> "bar") -- foobar
  logShow (true && not false) -- true
