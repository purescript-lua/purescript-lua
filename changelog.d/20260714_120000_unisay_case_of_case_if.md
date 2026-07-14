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

- Half-literal boolean ifs fold to short-circuiting operators (#203):
  `if p then True else b` becomes `p or b`, `if p then False else b` becomes
  `not p and b`, and the two mirrored shapes likewise — the completion of
  `reduceBooleanIf`, whose two-literal cases already collapsed to the bare
  condition. Lua's `and`/`or` evaluate exactly what the branches evaluated,
  in the same order, and unlike a branch an operator survives in condition
  position without an IIFE: the `Ordering` trees compared against `GT`
  (`Golden.Loopification`, `Golden.Primops`, `Golden.UncurryEffect`) now
  flatten all the way to `not (n < 0) and n ~= 0`. Two identity primop folds
  ride along (`a and true` → `a`, `a or false` → `a` — nothing is skipped);
  the annihilator duals stay, since folding them would skip evaluating `a`.
  Luacheck's W581 (suggesting the NaN-unsafe `not (x < y)` → `x >= y` flip)
  is now ignored for generated goldens.
