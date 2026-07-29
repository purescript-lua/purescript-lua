### Fixed

- The bottom-up IR rewrite driver — the traversal that rewrites a node's
  children before the node and then re-applies the rules to their own result
  until none fires — no longer loops forever on an expression that has no
  normal form (#348). The re-application loop was unbounded, so beta reduction
  spun on the self-application `Ω = (λx. x x) (λy. y y)`, whose every reduction
  step reproduces it modulo binder names:

  ```
  AppN (AbsN [x$400] (AppN x$400 [x$400])) [AbsN [x$401] (AppN x$401 [x$401])]
  AppN (AbsN [x$401] (AppN x$401 [x$401])) [AbsN [x$402] (AppN x$402 [x$402])]
  AppN (AbsN [x$402] (AppN x$402 [x$402])) [AbsN [x$403] (AppN x$403 [x$403])]
  ```

  The loop now stops after `maxNestedRewrites` (100) nested rewrites along one
  path and returns the term it has reached, the same treatment the pass-level
  fixpoint already gave its own iteration cap: every rewrite preserves
  semantics and the IR invariants on its own, so abandoning a redex
  mid-reduction costs optimization and nothing else, and the driver's
  `Rewritten` flag stays precise. With the pipeline's invariant checking on
  (`--lint-ir`, and the test suite) the residual redex surfaces as
  `FixpointDivergence "optimize+dce"` rather than as silence.

  Emitted code is unchanged and the whole golden corpus stays byte-identical:
  PureScript's type system rejects every term without a normal form, so no
  compiled program contains one, and a converging rule chain needs a handful of
  nested rewrites — the whole test suite, the ~300-deep golden constant chains
  included, peaks at five, twenty times clear of the bound. What the bug did
  cost was a test suite that hung rather than reddened, because the property
  `IR Optimizer / optimization keeps expressions well-scoped` feeds the
  optimizer generated untyped terms and drew `Ω` at 3 of the first 500 hspec
  seeds (109, 152 and 478), each of which now finishes the group in about five
  seconds.
