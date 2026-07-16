-- | Shape catalog for the result-side worker/wrapper split: functions whose
-- | every return path builds the same constructor, consumed by deconstructing
-- | sites (the product should never materialize) and by whole-value sites
-- | (the product must survive).
module Golden.CprResult.Test where

import Prelude

import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Console (logShow)

-- A step small enough for the call-site inliner: deconstructing sites
-- dissolve it wholesale, only the whole-value consumer keeps it alive.
step :: Int -> Tuple Int Int
step s = Tuple (s * 2) (s + 1)

useStep :: Int -> Int
useStep n = case step n of Tuple a s -> a + s

-- Whole-value consumer: the pair flows into `show` as one value.
pair :: Tuple Int Int
pair = step 10

-- Both branches return the same constructor, and the body is too big for
-- the call-site inliner, so only a result split can unbox the return.
branchy :: Int -> Tuple Int Int
branchy n =
  if n > 0 then
    let
      b1 = n + 7
      b2 = b1 + n
      b3 = b2 - 4
      b4 = b3 + b1
      b5 = b4 + b2
      b6 = b5 - b3
      b7 = b6 + b4
      b8 = b7 - b5
    in
      Tuple (b1 + b3 + b5 + b7) (b2 + b4 + b6 + b8)
  else
    let
      c1 = 3 - n
      c2 = c1 + 5
      c3 = c2 - n
      c4 = c3 + c1
      c5 = c4 + c2
      c6 = c5 - c3
      c7 = c6 + c4
      c8 = c7 - c5
    in
      Tuple (c1 + c3 + c5 + c7) (c2 + c4 + c6 + c8)

useBranchy :: Int -> Int
useBranchy n = case branchy n of Tuple a b -> a - b

-- Whole-value consumer of the branchy candidate: its wrapper must survive.
keepBranchy :: Tuple Int Int
keepBranchy = branchy 3

-- Straight-line body over the inline budget, consumed only by
-- deconstruction: the wrapper is dead code once every site goes to the
-- worker directly.
big :: Int -> Tuple Int Int
big n =
  let
    a1 = n + 1
    a2 = a1 + 3
    a3 = a2 - n
    a4 = a3 + a1
    a5 = a4 + 2
    a6 = a5 + a2
    a7 = a6 - a3
    a8 = a7 + a4
    a9 = a8 + 1
    a10 = a9 - a5
    a11 = a10 + a6
    a12 = a11 - a7
    a13 = a12 + a8
    a14 = a13 + a9
    a15 = a14 - a10
    a16 = a15 + a11
  in
    Tuple
      (a1 + a3 + a5 + a7 + a9 + a11 + a13 + a15)
      (a2 + a4 + a6 + a8 + a10 + a12 + a14 + a16)

useBig :: Int -> Int
useBig n = case big n of Tuple x y -> x + y

main :: Effect Unit
main = do
  logShow (useStep 5)
  logShow pair
  logShow (useBranchy 7)
  logShow (useBranchy (-7))
  logShow keepBranchy
  logShow (useBig 3)
