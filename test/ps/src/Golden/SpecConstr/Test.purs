-- | Exercises call-pattern specialization (issue #208): a recursive
-- | function that scrutinizes a parameter and passes a known
-- | constructor at that position in its recursive calls gets a
-- | specialized copy taking the constructor's fields as separate
-- | parameters, so the hot loop carries raw values instead of
-- | allocating a box per iteration. The eval oracle pins that every
-- | shape keeps its runtime behavior, specialized or not.
module Golden.SpecConstr.Test where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Console (logShow)

-- The canonical fold: a product-type accumulator built afresh on every
-- iteration and taken apart at the top of the next one. Specialization
-- carries the two fields as loop parameters; the box materializes only
-- on the exit path.
sumCount :: Int -> Tuple Int Int
sumCount n = go (Tuple 0 0)
  where
  go :: Tuple Int Int -> Tuple Int Int
  go acc = case acc of
    Tuple s i
      | i >= n -> acc
      | otherwise -> go (Tuple (s + i) (i + 1))

-- A sum-type accumulator: only the `Just` pattern recurs, so only it
-- is specialized; the `Nothing` arm stays on the boxed entry path.
stepDown :: Maybe Int -> Int
stepDown m = case m of
  Nothing -> 0
  Just i -> if i == 0 then 42 else stepDown (Just (i - 1))

-- Mutual recursion: each member's call sites live in the other's body,
-- and both carry the same constructor pattern.
ping :: Tuple Int Int -> Int
ping t = case t of
  Tuple a b -> if a == 0 then b else pong (Tuple (a - 1) (b + 1))

pong :: Tuple Int Int -> Int
pong t = case t of
  Tuple a b -> if a == 0 then b else ping (Tuple (a - 1) (b + 2))

-- Negative control: the boxed parameter is never scrutinized (it is
-- dead), so there is nothing to gain and the binding is left alone.
blind :: Int -> Tuple Int Int -> Int
blind n t = if n == 0 then 0 else blind (n - 1) (Tuple n n)

main :: Effect Unit
main = do
  logShow (sumCount 5)
  logShow (stepDown (Just 3))
  logShow (stepDown Nothing)
  logShow (ping (Tuple 4 10))
  logShow (blind 3 (Tuple 1 1))
