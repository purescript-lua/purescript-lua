### Fixed

- `@inline <name> never` now actually prevents inlining. The annotation was
  parsed and stored but never consulted as a veto: both inlining sites decided
  with `isInlinableExpr expr || <used once>`, so a `never`-annotated binding
  that was a reference, a small literal, or used once was still inlined. The
  optimizer now collects the `never`-annotated binding names once up front, so
  the veto survives later rewrites that drop the annotation, and refuses to
  inline those bindings regardless of the heuristic or the single-use rule
  (#131).
