### Changed

- Foreign accessors are no longer `@inline always` by default (#248). An
  accessor without a pragma now dissolves into its use site only when it has
  at most one; at two or more sites it is kept as a shared binding, which
  stage-2 promotion (#174) turns into a chunk local — every use becomes a
  register/upvalue read instead of a repeated table-field read. Explicit
  pragmas keep their meaning in both directions: `@inline <name> always`
  restores the per-site field read, `@inline <name> never` keeps the shared
  binding even when used once. Bodies lifted into the IR by the foreign-lift
  pass are still marked inline-always by that pass, since they exist to
  beta-reduce at saturated call sites.
