-- Issue #248: an unannotated foreign accessor used at two or more
-- sites is kept as a shared binding (promoted to a chunk local by the
-- Lua backend), while a single-use accessor keeps the dissolved form —
-- a field read at its one use site.
module Golden.ForeignAccessorDefault.Test (main) where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

foreign import double :: Int -> Int
foreign import bump :: Int -> Int

main :: Effect Unit
main = do
  logShow (double 21)
  logShow (double 4)
  logShow (bump 7)
