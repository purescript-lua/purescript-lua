module Golden.TailRecM2Shadow.Test where

import Prelude

import Control.Monad.Rec.Class (class MonadRec, Step(..), tailRecM2)
import Effect (Effect)
import Effect.Console (logShow)

-- Regression for #56. The outer parameter is named `b`, and `tailRecM2`'s own
-- third parameter is also `b`. `tailRecM2` is a single-use dictionary accessor,
-- so the optimizer inlines and beta-reduces it; reducing under the inner `b`
-- capture-shifts the outer reference to index 1, and removing that binder must
-- lower it back to 0. The optimizer used to skip the lowering, leaving an
-- unbound `Local b index 1` that aborted Lua codegen for `Data.Array.foldRecM`.
sumFrom :: forall m. MonadRec m => Int -> Int -> m Int
sumFrom b n = tailRecM2 go b 0
  where
  go acc i
    | i >= n = pure (Done acc)
    | otherwise = pure (Loop { a: acc + i, b: i + 1 })

main :: Effect Unit
main = do
  r <- sumFrom 0 5
  logShow r
