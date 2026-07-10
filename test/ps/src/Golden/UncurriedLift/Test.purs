-- | Exercises the lifting of the @*.Uncurried@ run wrappers to direct
-- | n-ary calls (issue #198).
-- |
-- | The pure @runFn2@/@runFn3@ sites must collapse to a single Lua call
-- | (@add3(1, 2, 3)@), not the curried-onion @runFn3(add3)(1)(2)(3)@. The
-- | effectful @runEffectFn2@ site sits in statement position, where magicDo
-- | fuses the run wrapper's thunk away to a direct @logTwice(a, b)@ — one
-- | call and no closures where the fallback paid four calls and three.
module Golden.UncurriedLift.Test where

import Prelude

import Data.Function.Uncurried (Fn2, Fn3, mkFn2, mkFn3, runFn2, runFn3)
import Effect (Effect)
import Effect.Console (log, logShow)
import Effect.Uncurried (EffectFn2, mkEffectFn2, runEffectFn2)

add3 :: Fn3 Int Int Int Int
add3 = mkFn3 \a b c -> a + b + c

mul2 :: Fn2 Int Int Int
mul2 = mkFn2 \a b -> a * b

logTwice :: EffectFn2 String String Unit
logTwice = mkEffectFn2 \a b -> do
  log a
  log b

-- A partial application: `runFn3 add3 1 2` supplies only two of add3's
-- three arguments, so this exported binding stays a function of the last —
-- lifted to a direct n-ary `add3(1, 2, c)`, the wrapper's curried-fallback
-- semantics without its closures. (Its saturated call sites in `main`
-- additionally inline to `add3(1, 2, n)`.)
addOnePlusTwoTo :: Int -> Int
addOnePlusTwoTo = runFn3 add3 1 2

main :: Effect Unit
main = do
  -- A non-tail effect statement: magicDo fuses the run wrapper's thunk
  -- away, so this becomes a direct `local _ = logTwice("hello", "world")`.
  runEffectFn2 logTwice "hello" "world" -- hello / world
  logShow (runFn3 add3 1 2 3) -- 6
  logShow (runFn2 mul2 4 5) -- 20
  logShow (addOnePlusTwoTo 100) -- 103
  logShow (addOnePlusTwoTo 200) -- 203
