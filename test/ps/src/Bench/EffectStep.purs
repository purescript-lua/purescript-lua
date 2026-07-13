-- | A hot ST loop through a unary effect step that is always fully
-- | applied and immediately run. Before the late uncurry run (issue
-- | #200) every iteration paid a curried call returning a freshly
-- | allocated thunk plus the call that forces it; after it the step is
-- | a single n-ary worker call with the thunk parameter absorbed.
module Bench.EffectStep where

import Prelude

import Control.Monad.ST (ST)
import Control.Monad.ST as ST
import Control.Monad.ST.Ref (STRef)
import Control.Monad.ST.Ref as STRef

-- Unary: below the split threshold until magicDo appends the thunk
-- parameter, so only the late uncurry run can split it. The body is
-- deliberately over the call-site inline budget, so the call shape
-- survives to be measured — built from read/write pairs, which unlike
-- @modify@ allocate no per-iteration lambda that would drown the
-- thunk-allocation delta this bench exists to expose.
step :: forall r. STRef r Int -> ST r Unit
step ref = do
  a <- STRef.read ref
  _ <- STRef.write (a + 1) ref
  b <- STRef.read ref
  _ <- STRef.write (b + 2) ref
  c <- STRef.read ref
  _ <- STRef.write (c + 3) ref
  d <- STRef.read ref
  _ <- STRef.write (d + 4) ref
  e <- STRef.read ref
  _ <- STRef.write (e + 5) ref
  pure unit

go :: forall r. Int -> STRef r Int -> ST r Int
go i ref = do
  step ref
  if i <= 1 then STRef.read ref else go (i - 1) ref

run :: Int -> Int
run n = ST.run do
  ref <- STRef.new 0
  go n ref
