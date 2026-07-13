-- @inline export addToAll never
-- @inline export runTwice never
-- @inline export catBoth never
-- @inline export classify never
module Golden.CSE.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- Two textually identical lambdas within one body: closure allocation
-- is pure, so a single shared allocation is enough.
addToAll :: Int -> Array Int -> Array Int
addToAll n xs = map (\i -> i + n) xs <> map (\i -> i + n) xs

-- The same field of an opaque record read twice within one body: a
-- projection out of a reference is effect-free, so one read can serve
-- both uses.
runTwice :: forall a. { run :: a -> a } -> a -> a
runTwice r x = r.run (r.run x)

-- The same pure array literal consumed twice within one body. The
-- enclosing applications `f [ ... ]` repeat too, but a function call is
-- never effect-free by construction, so both calls must stay.
catBoth :: (Array Int -> Array Int) -> Array Int
catBoth f = f [ 1, 2, 3 ] <> f [ 1, 2, 3 ]

data N = Zero | Succ N

data E = Num N | Not E

-- The pattern matcher repeats reads like `e[2][2][1]` across the arms,
-- but only under their tag guards: for the variant actually present the
-- inner slot can be nil, and reading through nil throws. Only the reads
-- over the scrutinee itself may be shared; the chained reads must stay
-- guarded. Calling `classify (Num Zero)` crashes if a chain is hoisted.
classify :: E -> Int
classify e = case e of
  Not (Num Zero) -> 0
  Not (Num (Succ _)) -> 1
  Not (Not _) -> 2
  Num Zero -> 3
  Num (Succ _) -> 4

main :: Effect Unit
main = do
  logShow (addToAll 10 [ 1, 2 ])
  logShow (addToAll 20 [ 3 ])
  logShow (runTwice { run: \i -> i * 2 } 3)
  logShow (runTwice { run: \i -> i - 1 } 10)
  logShow (catBoth (map (_ * 3)))
  logShow (catBoth identity)
  logShow (classify (Num Zero))
  logShow (classify (Num (Succ Zero)))
  logShow (classify (Not (Num Zero)))
  logShow (classify (Not (Not (Num Zero))))
