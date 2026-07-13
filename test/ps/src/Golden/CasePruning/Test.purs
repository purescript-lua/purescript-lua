-- @inline export literalRetest never
-- @inline export ctorRetest never
-- @inline export literalNegatives never
module Golden.CasePruning.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- The Data.String.CodePoints.codePointAt shape: clause 2 fails on its
-- second pattern, clause 3 re-tests 0 == n although the answer is
-- already decided on both paths.
literalRetest :: Int -> String -> Int
literalRetest 0 "" = 1
literalRetest 0 _ = 2
literalRetest _ _ = 3

data T = A | B | C

-- On the path where both A and B failed on the first scrutinee,
-- clause 3 re-tests A: negative knowledge must accumulate across
-- failed tags for the retest to be pruned.
ctorRetest :: T -> T -> Int
ctorRetest A A = 1
ctorRetest B B = 2
ctorRetest A B = 3
ctorRetest _ _ = 4

-- The literal twin of ctorRetest: a positive 1 == n excludes 2 == n,
-- and two accumulated negatives decide the retest of 1 == n.
literalNegatives :: Int -> Int -> Int
literalNegatives 1 1 = 1
literalNegatives 2 2 = 2
literalNegatives 1 2 = 3
literalNegatives _ _ = 4

main :: Effect Unit
main = do
  logShow (literalRetest 0 "")
  logShow (literalRetest 0 "x")
  logShow (literalRetest 5 "")
  logShow (ctorRetest A A)
  logShow (ctorRetest B B)
  logShow (ctorRetest A B)
  logShow (ctorRetest A C)
  logShow (ctorRetest C C)
  logShow (literalNegatives 1 1)
  logShow (literalNegatives 2 2)
  logShow (literalNegatives 1 2)
  logShow (literalNegatives 1 3)
  logShow (literalNegatives 3 3)
