-- | Minimal reproduction: `discard` instantiated with two different
-- | Bind dictionaries in one module (here ST and Effect; any second
-- | monad triggers it) makes the PureScript compiler's own CSE float
-- | the shared partial application in two stages:
-- |
-- |     discard  = Control.Bind.discard discardUnit
-- |     discard1 = discard bindST
-- |     discard2 = discard bindEffect
-- |
-- | The two-stage shape starves Effect/ST canonicalization and magic-do.
module Golden.MixedDiscardFloat.Test where

import Prelude

import Control.Monad.ST as ST
import Control.Monad.ST.Ref as STRef
import Effect (Effect)
import Effect.Console (log, logShow)

stCount :: Int
stCount = ST.run do
  r <- STRef.new 1
  void (STRef.write 2 r)
  STRef.read r

main :: Effect Unit
main = do
  log "st:"
  logShow stCount
