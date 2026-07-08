-- | Exercises module-table field localization (issue #174): a field of
-- | the module-scope table read repeatedly within one function
-- | activation is cached in a local at function entry, while single
-- | straight-line reads and reads belonging to other activations stay
-- | on the table. The eval oracle pins that caching moves reads without
-- | changing results.
-- @inline weigh never
-- @inline apply2 never
module Golden.FieldCaching.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- The shared helper; the pragma keeps it a top-level binding so its
-- call sites stay module-table reads.
weigh :: Int -> Int
weigh x = x * 2 + 1

-- Two straight-line reads of the same field: cached at entry.
pair :: Int -> Int
pair n = weigh n + weigh (n + 1)

-- A single straight-line read: caching would trade one table read for
-- the same read plus a local, so it is left alone.
single :: Int -> Int
single n = weigh n

-- The self-recursive tail call loopifies (issue #181); the single
-- static read inside the loop body re-evaluates per iteration, so it
-- still caches, hoisting the table read out of the loop.
sumLoop :: Int -> Int -> Int
sumLoop acc n = if n == 0 then acc else sumLoop (acc + weigh n) (n - 1)

-- Both recursive reads sit in the conditional branch: caching would
-- tax every base-case call with table reads it never performs (half
-- the calls of a leaf-heavy recursion), so nothing is cached here.
fibby :: Int -> Int
fibby n = if n < 2 then n else weigh (n - 1) + weigh (n - 2)

-- The reads sit inside an escaping closure: the cache belongs to the
-- closure's own activation, not the enclosing function's.
apply2 :: (Int -> Int) -> Int
apply2 f = f 2

closed :: Int -> Int
closed x = apply2 (\y -> weigh x + weigh y)

main :: Effect Unit
main = do
  logShow (pair 1)
  logShow (single 10)
  logShow (sumLoop 0 4)
  logShow (fibby 5)
  logShow (closed 5)
