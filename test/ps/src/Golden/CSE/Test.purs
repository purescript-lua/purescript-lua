-- @inline export addToAll never
-- @inline export runTwice never
-- @inline export catBoth never
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

main :: Effect Unit
main = do
  logShow (addToAll 10 [ 1, 2 ])
  logShow (addToAll 20 [ 3 ])
  logShow (runTwice { run: \i -> i * 2 } 3)
  logShow (runTwice { run: \i -> i - 1 } 10)
  logShow (catBoth (map (_ * 3)))
  logShow (catBoth identity)
