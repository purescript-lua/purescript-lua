module Golden.DirectivePack.Test where

import Prelude

import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe(..))
import Data.Show.Generic (genericShow)
import Effect (Effect)
import Effect.Console (log)
import Effect.Ref as Ref

-- No @inline pragmas anywhere: every combinator below inlines through
-- the default directive pack the compiler ships for the prelude/core
-- forks (bindFlipped, the function-instance Semigroup/Category methods,
-- otherwise, the generics glue, and the Ref modify wrappers).

data Fruit = Apple | Banana Int

derive instance Generic Fruit _

instance Show Fruit where
  show = genericShow

half :: Int -> Maybe Int
half n = if n `mod` 2 == 0 then Just (n / 2) else Nothing

-- A flipped-bind chain: bindFlipped => flip => bind unfold at each site
-- and the Maybe binds collapse.
chain :: Maybe Int
chain = half =<< half =<< half =<< Just 40

-- Semigroup on functions: `f <> g` goes through the semigroupFn
-- dictionary's append field.
describeFruit :: Fruit -> String
describeFruit = const "fruit: " <> show

-- Category on functions: identity vanishes, <<< goes through the
-- semigroupoidFn dictionary's compose field.
pipeline :: Int -> Int
pipeline = identity <<< (_ + 1) <<< identity

classify :: Int -> String
classify n
  | n < 0 = "negative"
  | n == 0 = "zero"
  | otherwise = "positive"

main :: Effect Unit
main = do
  log (show chain)
  log (describeFruit (Banana 3))
  log (show (pipeline 41))
  log (classify 7)
  r <- Ref.new 10
  Ref.modify_ (_ * 3) r
  v <- Ref.read r
  log (show v)
