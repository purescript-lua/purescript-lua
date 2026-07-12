-- | Effect and ST @do@ blocks in one module (issue #182): a canary for
-- | the compiler's common-subexpression elimination floating a partial
-- | dictionary application (e.g. @discard discardUnit@) shared across
-- | the two monads' dictionaries.
-- |
-- | Both chains must lower to flat thunks; neither may keep the other
-- | from being recognised.
module Golden.MixedEffectSTDo.Test where

import Prelude

import Control.Monad.ST as ST
import Control.Monad.ST.Ref as STRef
import Effect (Effect)
import Effect.Console (log, logShow)

tally :: Int -> Int
tally start = ST.run do
  ref <- STRef.new start
  _ <- STRef.modify (_ * 2) ref
  n <- STRef.read ref
  pure (n + 3)

main :: Effect Unit
main = do
  log "mixing Effect and ST"
  x <- pure (tally 2)
  logShow x
  log "done"
