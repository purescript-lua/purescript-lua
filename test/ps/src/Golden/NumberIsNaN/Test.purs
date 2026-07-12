module Golden.NumberIsNaN.Test where

import Prelude

import Data.Number (infinity, isNaN, nan)
import Effect (Effect)
import Effect.Console (logShow)

main :: Effect Unit
main = do
  logShow (isNaN nan)
  logShow (isNaN (negate nan))
  logShow (isNaN (infinity - infinity))
  logShow (isNaN 42.0)
  logShow (isNaN infinity)
