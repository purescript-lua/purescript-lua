### Added

- Case-of-case pushes over the `IfThenElse` decision tree in the IR optimizer
  (#203). A scalar literal compared against an if-tree distributes into the
  branches when every leaf comparison constant-folds — the shape an inlined
  `Ord` comparison leaves behind once the tag read distributes over its
  `Ordering` tree (#180) — and an if sitting in the condition of another if
  pushes into its branches when the inner branches are boolean literals or
  the outer branches are trivial to re-emit. Both shapes sat in expression
  position, where codegen wraps them in an IIFE allocated and called per
  evaluation — on every iteration, for the recursive functions in
  `Golden.LongCallbackChain` and `Golden.TailRecM2Shadow`. The pushed
  comparison collapses to a flat condition — `if n < 0 then` instead of
  `if "…LT" == (function() … end)() then` — across seven goldens, with eval
  outputs unchanged.
