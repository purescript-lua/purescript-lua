-- | Exercises the lifting of the @#@-shaped @length@ foreigns to the
-- | unary length primop (issue #247).
-- |
-- | @Data.Array.length@ and @Data.String.CodeUnits.length@ are both
-- | one-line wrappers around Lua's @#@ in the forks
-- | (@function(xs) return #xs end@). Lifted, a saturated site must
-- | collapse to a bare @#xs@ — the VM's own length opcode — instead of a
-- | read off the foreign table plus a call frame, and the lifted rows
-- | must drop out of the emitted FFI tables. @countBelow@ puts the read
-- | in a loop condition, the hot shape the lift exists for.
-- |
-- | @lengthsAroundPush@ is the counterweight. @Data.Array.ST.length@
-- | goes through the byte-identical @function(xs) return #xs end@, yet
-- | @lengthImpl@ stays off the lift allowlist: it is an @STFn1@, so its
-- | call is an effect statement, and codegen sheds the surrounding
-- | effect thunk only for a /call/ body — a lifted length body would
-- | keep the thunk and pay a closure allocation on top of the call it
-- | replaced. The Lua golden pins that, holding both reads at a direct
-- | @Data_Array_ST_lengthImpl(arr)@.
module Golden.LengthLift.Test where

import Prelude

import Control.Monad.ST as ST
import Data.Array as Array
import Data.Array.ST as STArray
import Data.String.CodeUnits as CodeUnits
import Effect (Effect)
import Effect.Console (logShow)

countOf :: Array Int -> Int
countOf = Array.length

widthOf :: String -> Int
widthOf = CodeUnits.length

-- The length read sits in the loop's guard, so it is evaluated once per
-- iteration — the per-iteration call frame the lift removes.
countBelow :: Array Int -> Int
countBelow xs = go 0 0
  where
  go acc i
    | i < Array.length xs = go (acc + i) (i + 1)
    | otherwise = acc

lengthsAroundPush :: Array Int
lengthsAroundPush = ST.run do
  arr <- STArray.thaw [ 1, 2, 3 ]
  before <- STArray.length arr
  _ <- STArray.push 4 arr
  after <- STArray.length arr
  pure [ before, after ]

main :: Effect Unit
main = do
  logShow (countOf [ 10, 20, 30 ]) -- 3
  logShow (widthOf "hello") -- 5
  logShow (countBelow [ 10, 20, 30, 40 ]) -- 6
  logShow lengthsAroundPush -- [3,4]
