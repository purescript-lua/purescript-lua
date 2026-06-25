### Changed

- Documented the optimizer's `Note [IR is assumed well-typed]`, cited from the
  constant-folding and beta-reduction rewrites that rely on it, and made the
  conscious calls on the remaining low-priority candidates from #44 (leaving the
  already-adequate inline comments in place). This closes out the GHC-style
  `Note` documentation pass (#44). Comments only; no change to generated code.
