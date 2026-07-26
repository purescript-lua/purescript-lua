-- @inline ops.mul never
-- @inline mkOps...add always
module Golden.DirectiveAccessor.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log)

type Ops =
  { add :: Int -> Int -> Int
  , mul :: Int -> Int -> Int
  }

-- A dictionary record: .mul is pinned behind the dictionary, so both
-- call sites below stay field reads instead of resolving to the method.
ops :: Ops
ops =
  { add: \a b -> a + b
  , mul: \a b -> a * b
  }

type Ops4 =
  { add :: Int -> Int -> Int
  , sub :: Int -> Int -> Int
  , mul :: Int -> Int -> Int
  , divide :: Int -> Int -> Int
  }

-- A dictionary constructor too large for the default call-site budget:
-- only the ...add directive lets `(mkOps 1).add` resolve; the
-- undirected `(mkOps 2).mul` stays a projection of the application.
-- The size padding subtracts, because an added constant chain would
-- reassociate into one literal and collapse the over-budget premise.
mkOps :: Int -> Ops4
mkOps n =
  { add: \a b -> a + b + n - 10 - 20 - 30 - 40 - 50 - 60
  , sub: \a b -> a - b + n - 10 - 20 - 30 - 40 - 50 - 60
  , mul: \a b -> a * b + n - 10 - 20 - 30 - 40 - 50 - 60
  , divide: \a b -> a * 2 + b * 3 + n - 10 - 20 - 30 - 40
  }

main :: Effect Unit
main = do
  log (show (ops.mul 6 7))
  log (show (ops.mul 2 3))
  log (show ((mkOps 1).add 20 21))
  log (show ((mkOps 2).mul 3 4))
