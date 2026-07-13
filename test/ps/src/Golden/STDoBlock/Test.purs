-- | An ST @do@ chain (issue #182): @STRef@ binds terminated by @pure@,
-- | run with @ST.run@.
-- |
-- | Magic-do must lower the ST chain exactly like an Effect one — the
-- | @Control.Monad.ST.Internal@ dictionaries resolve to @bind_@/@pure_@
-- | — leaving a flat thunk and no dictionary-application residue.
module Golden.STDoBlock.Test where

import Prelude

import Control.Monad.ST as ST
import Control.Monad.ST.Ref as STRef
import Effect (Effect)
import Effect.Console (logShow)

sumTwice :: Int -> Int
sumTwice n = ST.run do
  ref <- STRef.new 0
  _ <- STRef.modify (_ + n) ref
  _ <- STRef.modify (_ + n) ref
  total <- STRef.read ref
  pure (total + 1)

main :: Effect Unit
main = logShow (sumTwice 5)
