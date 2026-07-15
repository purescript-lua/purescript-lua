-- | Exercises data-constructor construction end to end across every shape
-- | the uncurrying change touches: a saturated arity-3 sum constructor
-- | (splits into an n-ary worker/curried wrapper), a saturated arity-2
-- | product constructor (no tag row), an arity-1 sum constructor pasted
-- | in place, nullary singletons, a partial application stored and reused
-- | (the curried wrapper), a constructor passed higher-order (`map Just`),
-- | newtype construction (erased), and a recursive `Cons` spine built into
-- | a moderately long literal and folded back. The eval oracle pins that
-- | the transformation preserves runtime behaviour for every shape.
module Golden.UncurryCtor.Test where

import Prelude

import Data.Maybe (Maybe(..), maybe)
import Effect (Effect)
import Effect.Console (logShow)

-- A sum type mixing arities: `Tri` is arity 3 (splits into a worker plus a
-- curried wrapper), `Dot` is arity 1 (pasted in place at a saturated site),
-- and `Origin` is a nullary singleton (shared, never re-allocated).
data Shape
  = Origin
  | Dot Int
  | Tri Int Int Int

-- A single-constructor type is a ProductType: no tag row, arity-2 ctor.
data Pair = Pair Int Int

-- Newtype construction is erased to the identity.
newtype Boxed = Boxed Int

-- A recursive constructor, built into a spine and folded back.
data IntList = Nil | Cons Int IntList

area :: Shape -> Int
area = case _ of
  Origin -> 0
  Dot r -> r
  Tri a b c -> a + b + c

pairSum :: Pair -> Int
pairSum (Pair x y) = x + y

unbox :: Boxed -> Int
unbox (Boxed n) = n

-- A nested `Cons` spine: a moderately long in-place constructor nest that
-- keeps the deep-nesting checks honest.
range :: IntList
range =
  Cons 1
    (Cons 2
      (Cons 3
        (Cons 4
          (Cons 5
            (Cons 6
              (Cons 7
                (Cons 8
                  (Cons 9
                    (Cons 10 Nil)))))))))

total :: IntList -> Int
total = case _ of
  Nil -> 0
  Cons x xs -> x + total xs

main :: Effect Unit
main = do
  -- Saturated arity-3 sum constructor.
  logShow (area (Tri 3 4 5))
  -- Saturated arity-1 sum constructor.
  logShow (area (Dot 9))
  -- Nullary singleton.
  logShow (area Origin)
  -- Saturated arity-2 product constructor.
  logShow (pairSum (Pair 20 22))
  -- Newtype construction.
  logShow (unbox (Boxed 41))
  -- A partial application of a constructor, stored and reused: the curried
  -- wrapper must keep serving this shape.
  let mk = Tri 1 2
  logShow (area (mk 3))
  logShow (area (mk 30))
  -- A constructor passed higher-order, then eliminated.
  logShow (map (maybe 0 identity) (map Just [ 1, 2, 3 ]))
  -- A recursive build folded back to a sum.
  logShow (total range)
