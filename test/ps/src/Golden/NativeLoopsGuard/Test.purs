-- | Same-named loop combinators defined outside Effect/ST: the
-- | native-loop lowering (issue #233) keys on qualified names, so these
-- | must stay ordinary calls. Each combinator deliberately performs at
-- | most one step — a name-only match would iterate for real, change
-- | the printed output, and fail the eval golden.
module Golden.NativeLoopsGuard.Test where

import Prelude

import Data.Array (head)
import Data.Maybe (maybe)
import Effect (Effect)
import Effect.Console (log, logShow)
import Effect.Ref as Ref

forE :: Int -> Int -> (Int -> Effect Unit) -> Effect Unit
forE lo hi f = when (lo < hi) (f lo)

foreachE :: forall a. Array a -> (a -> Effect Unit) -> Effect Unit
foreachE xs f = maybe (pure unit) f (head xs)

whileE :: Effect Boolean -> Effect Unit -> Effect Unit
whileE cond act = do
  b <- cond
  when b act

main :: Effect Unit
main = do
  forE 1 5 logShow
  foreachE [ "x", "y" ] log
  r <- Ref.new 3
  whileE (map (_ > 0) (Ref.read r)) do
    n <- Ref.read r
    logShow n
    Ref.modify_ (_ - 1) r
  log "guard done"
