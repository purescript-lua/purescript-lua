-- | Distribution of an accessor or application applied to a conditional
-- | into its branches (issue #243): the conditional otherwise sits in
-- | expression position — an IIFE in the generated Lua — hiding the
-- | projection or call from the folds that fire once it reaches the
-- | branch bodies. The eval oracle pins that distribution moves code
-- | without changing results.
-- @inline pickName never
-- @inline chooseName never
-- @inline applyPicked never
-- @inline applyExpensive never
-- @inline weigh never
module Golden.DistributeIntoIf.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log, logShow)

-- Opaque condition the optimizer cannot see through, so the
-- conditionals below survive to codegen.
foreign import flag :: Boolean

-- The projection distributes into the branches, each read folds to its
-- field value, and the conditional lands in statement position.
pickName :: Boolean -> String
pickName b = (if b then { name: "big" } else { name: "small" }).name

-- Opaque records: nothing folds, but the distributed reads still lift
-- the conditional out of expression position.
chooseName :: Boolean -> { name :: String } -> { name :: String } -> String
chooseName b l r = (if b then l else r).name

-- The call distributes over the branch lambdas and beta-reduces: the
-- IIFE and both closure allocations disappear.
applyPicked :: Boolean -> Int -> Int
applyPicked b n = (if b then (_ + 1) else (_ * 2)) n

weigh :: Int -> Int
weigh x = x * 3

-- The argument is a call — real work whose copies the push would paste
-- into both branches — so the distribution is declined and the
-- conditional keeps its expression position.
applyExpensive :: Boolean -> Int -> Int
applyExpensive b n = (if b then (_ + 1) else (_ * 2)) (weigh n)

main :: Effect Unit
main = do
  log (pickName flag)
  log (pickName (not flag))
  log (chooseName flag { name: "left" } { name: "right" })
  logShow (applyPicked flag 10)
  logShow (applyExpensive (not flag) 10)
