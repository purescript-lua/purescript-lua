module Golden.Primops.Test where

import Prelude
import Effect (Effect)
import Effect.Console (log, logShow)

-- Recursive, so the lifted arithmetic survives as direct Lua operators
-- over the variables `acc` and `n` (`acc + n`, `n - 1`) rather than
-- folding to a constant. The `n <= 0` guard still routes through the
-- lifted `compare` (whose body uses the `<`/`==` primops); collapsing
-- that dictionary dispatch to a direct comparison is #180.
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
