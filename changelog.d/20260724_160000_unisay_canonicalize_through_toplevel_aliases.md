### Fixed

- Mixed-monad `discard` chains no longer miscompile to a runtime nil
  call (#297). When one module instantiates `discard` with two different
  Bind dictionaries — Effect or ST plus any second monad — the
  PureScript compiler's own CSE floats the shared partial application in
  two stages —

  ```
  discard  = Control.Bind.discard discardUnit
  discard1 = discard bindST
  discard2 = discard bindEffect
  ```

  — a shape neither canonicalization tier matched: the Effect/ST chains
  stayed nested past magic-do, and once post-magic-do call-site inlining
  exposed the canonical pair, the tier-2 rewrite manufactured a reference
  to a foreign accessor binding dead-code elimination had already
  removed. The generated Lua read a never-assigned module-table field and
  crashed on first use:

  ```lua
  local M = {}
  ...
  return M.Effect_bindE(Effect_Console_log("st:"))(...)()  -- nil call
  ```

  Tier 2 now resolves head positions through top-level aliases before
  matching the canonical table — closed under any CSE split of the
  structurally bounded spines — so the chains flatten again, and it
  declines a rewrite whose produced reference the module can no longer
  resolve. Independently, the compiler now refuses to emit code for an
  optimized module with dangling imported references
  (`lintDanglingImports`), so any future resurrect-after-DCE fails the
  build instead of shipping broken Lua; the golden harness applies the
  same closedness check to every golden module.
