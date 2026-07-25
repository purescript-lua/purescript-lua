-- | Exercises join points (issue #234): a let-bound helper only ever
-- | tail-called from the enclosing body loses its function shell — the
-- | entry calls become parameter assignments falling through into the
-- | helper's body (a loop when the helper is self-recursive). The eval
-- | oracle pins that every shape keeps its runtime behavior, fused or
-- | not.
module Golden.JoinPoints.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- A where-bound self-recursive worker whose only outside use is the
-- body's tail call: the entry call is assimilated into the worker's
-- loop (composes with #181 loopification).
sumTriangles :: Int -> Int
sumTriangles m = go 0 m
  where
  go :: Int -> Int -> Int
  go acc n = if n == 0 then acc else go (acc + n * (n + 1)) (n - 1)

-- The recursive worker is tail-called from two branches of the body:
-- both entries fall through into one loop.
collatzish :: Int -> Int
collatzish n = if n > 100 then go 0 n else go 1 (n + 3)
  where
  go :: Int -> Int -> Int
  go acc k = if k <= 0 then acc else go (acc + 1) (k - 2)

-- A non-recursive shared continuation called in tail position from two
-- branches — a classic join point; loses the call without any loop.
classify :: Int -> Int
classify n =
  let finish r = (r * 10 + r) * 2 - r
  in if n > 0 then finish (n + 1) else finish (0 - n)

-- The helper escapes into a closure, so it must stay a real function:
-- the join transform must not fire.
escaping :: Int -> (Int -> Int)
escaping n =
  let go acc = if acc >= n then acc else go (acc + 1)
  in \m -> go m

-- A join point in effect land: the continuation is tail-called from
-- both branches of an effectful body.
chooseEff :: Int -> Effect Unit
chooseEff n =
  let report m = logShow (m * 2)
  in if n > 0 then report n else report (0 - n)

main :: Effect Unit
main = do
  logShow (sumTriangles 4)
  logShow (collatzish 10)
  logShow (collatzish 200)
  logShow (classify 3)
  logShow (classify (-2))
  logShow ((escaping 5) 2)
  chooseEff 4
  chooseEff (-3)
