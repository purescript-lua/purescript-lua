### Changed

- Documented three more IR invariants as GHC-style `Note`s, cited from their
  dependent sites: `Note [Inline annotations and inlining heuristics]` (how an
  `@inline` pragma travels from a comment through the annotation map and the
  expression `ann` to the optimizer's decision, plus the linker's synthesised
  `Inline.Always`), `Note [Inliner annotations must all be consumed]` (the
  annotation map is a linear resource whose leftovers `runRepM` reports, which
  is how a typo'd pragma surfaces), and `Note [Newtype constructors are erased]`
  (the three `isNewtype` sites where construction is identity, application
  unwraps, and matching skips the constructor). The `Ref` `Index` type now also
  points at the existing `Note [Sequential scoping of Let bindings]`, which
  already covers the per-name De Bruijn scheme. Comments only; no change to
  generated code. Continues #44.
