### Changed

- The IR rewrite driver is now bottom-up and `Maybe`-based. Rules return
  `Nothing` (did not fire) or `Just` a rewritten node, replacing the bespoke
  `Rewritten NoChange/Recurse/Stop` tri-state that conflated change reporting
  with descent control; the driver rewrites children before their parent and
  re-applies rules to their own results, so one optimizer pass is complete and
  idempotent, and the driver's change flag is precise — the groundwork for
  replacing the whole-module `Eq` fixpoint check (#144). The magic-do and
  deep-bind-flattening lowerings keep a (`Maybe`-based) top-down driver, since
  they consume chains from the outermost head. Generated code can differ in
  minted-name numbering and in the shapes the reordered rules normalize;
  runtime behavior is unchanged (all eval oracles hold).

### Fixed

- Three optimizer rules no longer report a rewrite when they change nothing:
  the DCE lambda rule fired on every unused-parameter lambda (#145), the DCE
  `Let` rule fired on every `Let`, and `inlineLocalBindings` fired on every
  `Let` even when nothing was inlined. A zero-occurrence inline substitution is
  now recognized as the no-op it is.
