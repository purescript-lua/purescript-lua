-- | A short State do-block: every bind threads a `Tuple result state`
-- | through the chain. The result-side worker/wrapper split deliberately
-- | does not fire here yet — the StateT dictionary bind chain is not
-- | collapsed by the budgeted inliner, so no manifest Tuple-returning
-- | candidate exists — and this golden pins exactly that boundary: its
-- | output moves the day chain collapsing reaches these shapes.
module Golden.CprState.Test where

import Prelude

import Control.Monad.State (State, evalState, get, put)
import Effect (Effect)
import Effect.Console (logShow)

go :: State Int Int
go = do
  x1 <- get
  put (x1 + 1)
  x2 <- get
  put (x2 + 1)
  x3 <- get
  put (x3 + 1)
  x4 <- get
  put (x4 + 1)
  x5 <- get
  put (x5 + 1)
  x6 <- get
  put (x6 + 1)
  x7 <- get
  put (x7 + 1)
  x8 <- get
  put (x8 + 1)
  x9 <- get
  put (x9 + 1)
  x10 <- get
  put (x10 + 1)
  final <- get
  pure (x1 + x5 + final)

main :: Effect Unit
main = logShow (evalState go 0)
