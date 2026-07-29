-- | A hot ST loop through a *two*-argument effect step that is always
-- | fully applied and immediately run — the case the late uncurry run
-- | (issue #200) cannot reach. With two real arguments the step's spine
-- | is already saturated when the early uncurry run measures it, so the
-- | split fires at the real arity and magicDo then rewrites the worker's
-- | body into a thunk: every iteration allocates that closure and pays
-- | the second call that forces it. Absorbing the thunk parameter into
-- | the worker makes the iteration one n-ary call with no allocation.
-- | `Bench.EffectStep` is the unary sibling, which the late run already
-- | handles.
module Bench.EffectStep2 where

import Prelude

import Control.Monad.ST (ST)
import Control.Monad.ST as ST
import Control.Monad.ST.Ref (STRef)
import Control.Monad.ST.Ref as STRef

-- Two real arguments, so the early run splits it and the thunk ends up
-- inside the worker. The body is deliberately over the call-site inline
-- budget, so the call shape survives to be measured — built from
-- read/write pairs, which unlike @modify@ allocate no per-iteration
-- lambda that would drown the thunk-allocation delta this bench exposes.
step :: forall r. Int -> STRef r Int -> ST r Unit
step k ref = do
  a <- STRef.read ref
  _ <- STRef.write (a + k) ref
  b <- STRef.read ref
  _ <- STRef.write (b + k) ref
  c <- STRef.read ref
  _ <- STRef.write (c + k) ref
  d <- STRef.read ref
  _ <- STRef.write (d + k) ref
  e <- STRef.read ref
  _ <- STRef.write (e + k) ref
  pure unit

go :: forall r. Int -> STRef r Int -> ST r Int
go i ref = do
  step 3 ref
  if i <= 1 then STRef.read ref else go (i - 1) ref

run :: Int -> Int
run n = ST.run do
  ref <- STRef.new 0
  go n ref
