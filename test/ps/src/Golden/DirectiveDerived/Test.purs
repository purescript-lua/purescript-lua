-- @inline combine arity=2
-- @inline apply34 never
module Golden.DirectiveDerived.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log)

-- A body over the inliner's size budget: a subtraction chain headed by
-- the last parameter, so nothing folds until a site supplies it. Only
-- a directive can paste it.
combine :: Int -> Int -> Int -> Int
combine a b c =
  c - a - 1 - b - 2 - a - 3 - b - 4 - a - 5 - b - 6 - a - 7 - b - 8
    - a - 9 - b - 10 - a - 11 - b - 12 - a - 13 - b - 14 - a - 15 - b - 16
    - a - 17 - b - 18 - a - 19 - b - 20

-- Saturated at the directed arity: derives always-inline, so each
-- applied site pastes the specialization and folds to a constant, with
-- no pragma on this binding.
onePlusTwo :: Int -> Int
onePlusTwo = combine 1 2

-- One argument short of the directed arity: derives arity=1 — applied
-- sites paste, while the bare use below keeps the shared binding.
oneOnly :: Int -> Int -> Int
oneOnly = combine 1

apply34 :: (Int -> Int -> Int) -> Int
apply34 f = f 3 4

main :: Effect Unit
main = do
  log (show (onePlusTwo 100))
  log (show (onePlusTwo 200))
  log (show (oneOnly 50 60))
  log (show (apply34 oneOnly))
