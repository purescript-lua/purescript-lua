-- @inline runOp arity=1
module Golden.DirectiveArity.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log)

data Op = Op (Int -> Int)

-- A user abstraction: without the arity directive it stays a shared
-- binding and every call goes through the `case`. Directed at arity=1,
-- each applied site pastes the body, meets case-of-known-constructor,
-- and collapses to the wrapped function's own body.
runOp :: Op -> Int -> Int
runOp op x = case op of Op f -> f x

main :: Effect Unit
main = do
  log (show (runOp (Op (_ + 1)) 41))
  log (show (runOp (Op (_ * 2)) 21))
