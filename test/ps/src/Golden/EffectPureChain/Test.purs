-- | An Effect @do@ chain interleaved with @pure@: a mid-chain
-- | @x <- pure …@ statement and a @pure@-terminated tail (issue #182).
-- |
-- | Magic-do must lower the whole chain into one flat thunk with the
-- | @pure@ steps collapsed to plain locals (@local x = …@, no
-- | dictionary-application residue), and the @pure@ tail to a direct
-- | @return@ of its argument.
module Golden.EffectPureChain.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log, logShow)

count :: Int -> Effect Int
count n = do
  log ("counting from " <> show n)
  x <- pure (n + 1)
  log ("got " <> show x)
  y <- pure (x * 2)
  pure (x + y)

main :: Effect Unit
main = do
  total <- count 20
  logShow total
