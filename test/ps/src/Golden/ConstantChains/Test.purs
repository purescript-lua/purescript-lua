module Golden.ConstantChains.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log, logShow)

-- Opaque values the optimizer cannot see through, so the chains below
-- keep their variable operands and only the constants coalesce.
foreign import anInt :: Int
foreign import anotherInt :: Int
foreign import aString :: String

main :: Effect Unit
main = do
  logShow (1 + anInt + 2 + anotherInt + 3)
  logShow (2 * anInt * 30)
  -- Parenthesized to the left so the literals are adjacent only after
  -- the concat spine is flattened (`<>` alone associates to the right,
  -- where plain pairwise folding already reaches the literal tail).
  log ((aString <> ", ") <> "world")
