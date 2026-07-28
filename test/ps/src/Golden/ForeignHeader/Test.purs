-- | Pins the header condition of the single-use foreign-import fold
-- | (#251). The import is read exactly once, from the right-hand side of
-- | the shared accessor `tag` — a once-evaluated position — so only the
-- | header statement in `Test.lua` holds the table hoisted: its effects
-- | run at a fixed point in module init, and folding the import into the
-- | accessor would move them.
-- |
-- | `Golden.ForeignAccessorDefault.Test` is the same shape over
-- | header-free sources, where the pair does collapse.
module Golden.ForeignHeader.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log)

foreign import tag :: String

main :: Effect Unit
main = do
  log tag
  log tag
