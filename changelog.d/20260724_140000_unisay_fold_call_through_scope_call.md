### Added

- A call applied to the result of an IIFE folds into its returns. The
  "pick a thunk, then run it" codegen shape — a scope call immediately
  applied, `(function() … end)()()` or `(function() … end)()(b)` — kept a
  closure allocation and an extra call per invocation that the
  tail-position collapse could not touch, because the applied result, not
  the scope call itself, sat in tail position. The new
  `foldCallThroughScopeCall` rule rewrites
  `(function() …; return e end)()(args)` to
  `(function() …; return e(args) end)()`, pushing the application into the
  tail returns — through a branching tail (`if … then return f else return
  g end`) as well, where the thunk selection lives. Evaluation order is
  preserved (leading statements, then the returned expression, then the
  arguments, in both forms), and `return e(args)` is a tail call, so even
  the activation depth at the moment the result runs is unchanged. The
  rule declines on early returns, fall-off paths (the original would call
  `nil` and error), multi-valued returns, arguments whose free names a
  body local would capture, varargs among the arguments, and non-atomic
  arguments on a branching tail (they would be syntactically duplicated
  per return site). The exposed plain scope call is then spliced away by
  `collapseTailScopeCall`, which now re-applies itself to the merged
  body — the fold builds tails at depths the bottom-up driver has already
  passed. Thirteen goldens shrink: `Golden.UncurryEffect.Test`'s
  `countdown` loses both tail closures, `Golden.TailRecM2Shadow.Test`'s
  `untilE` predicate drops its per-iteration selection closure, and the
  long-bind family runs its final effect directly. Eval goldens are
  unchanged.
