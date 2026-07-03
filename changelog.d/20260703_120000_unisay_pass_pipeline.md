### Added

- A `--lint-ir` debug flag: checks IR well-scopedness invariants before and
  after every optimizer pass (including every fixpoint iteration) and fails
  compilation naming the offending pass. The same checks always run in the
  test suite, so every golden module now doubles as a scope-invariant test
  of the whole pipeline (#138).

### Changed

- The IR optimization pipeline is restructured into first-class passes:
  each pass is a value carrying its invariant contract, sequenced by a
  runner instead of plain function composition. Fresh names are drawn from
  a deterministic supply. No change to generated code (#138).
