### Changed

- Top-level bindings the linked program actually reads are now promoted to
  real Lua chunk locals instead of living exclusively in the module-scope
  table `M` (#174 stage 2, `Language.PureScript.Backend.Lua.Promote`).
  Bindings are ranked by static read count and promoted while a locals
  budget allows; a bottom-up upvalue accounting per function proto demotes
  individual references back to `M.x` (mirroring the binding into `M`) when
  a function would otherwise exceed the target's upvalue limit, so the
  worst case is exactly today's `M`-only output. A program whose bindings
  and references all fit the budgets emits no `M` table at all. Runs before
  the existing per-function field caching (#174 stage 1), so that pass now
  only ever caches the residual `M` traffic. Structural goldens churn
  mechanically; eval goldens are unchanged.
