### Fixed

- `@inline <name> never` now actually prevents inlining. The annotation was
  parsed and stored but never consulted as a veto: both inlining sites decided
  with `isInlinableExpr expr || <used once>`, so a `never`-annotated binding
  that was a reference, a small literal, or used once was still inlined. A new
  `inlineForbidden` check now vetoes inlining of any `Just Never` binding at
  both sites, overriding the heuristic and the single-use rule (#131).
