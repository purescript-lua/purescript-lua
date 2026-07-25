-- | Canary for a known limitation of the native-loop lowering (#233).
-- |
-- | Recognition matches a combinator head in two forms — a direct
-- | imported reference and the dissolved foreign-accessor read — but
-- | does not resolve a top-level alias, the way magic-do's chain-head
-- | recognition does (`isCanonicalHead` resolves one hop). The
-- | optimizer normally dissolves such an alias before code generation,
-- | so the gap is unreachable on ordinary code; the `inline never`
-- | directive in `directives.txt` next to these goldens pins the alias
-- | undissolved and exposes it.
-- |
-- | `golden.lua` therefore pins the UNLOWERED shape — the foreign call
-- | `myFor(1)(3)(f)()`. That is the current limitation, not the target.
-- | When recognition moves into the IR (#239 needs the loop visible to
-- | the optimizer anyway), this golden should flip to a native `for`,
-- | and that flip is the proof the move closed the gap.
-- |
-- | Semantics are unaffected either way — the foreign combinator and
-- | the emitted loop iterate identically — so `eval/golden.txt` holds
-- | across the flip and only `golden.lua` discriminates.
-- |
-- | `Golden.NativeLoops.Test` covers the same alias without the
-- | directive, where the lowering does fire.
module Golden.NativeLoopsAliasPin.Test where

import Prelude

import Effect (Effect, forE)
import Effect.Console (log, logShow)

-- Applied at two call sites, so single-use inlining cannot dissolve the
-- alias even without the directive.
myFor :: Int -> Int -> (Int -> Effect Unit) -> Effect Unit
myFor = forE

main :: Effect Unit
main = do
  log "first:"
  myFor 1 3 logShow
  log "second:"
  myFor 5 7 logShow
