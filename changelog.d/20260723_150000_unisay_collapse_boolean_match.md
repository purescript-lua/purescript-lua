### Added

- Boolean pattern matches — including every inlined `show` of a `Boolean` —
  collapse to a two-way `if` (#223). A match on a `Boolean` compiled to a
  three-way `if` with a synthesized default (`if a then … elseif false == a
  then … else error("No patterns matched") end`), although `true`/`false`
  already cover the type: the re-test was opaque to the optimizer and the dead
  default was printed verbatim. Two additions reduce it. The boolean-equality
  fold in `constantFolding` is completed — `false == b` and `b == false` fold
  to `not b`, `b == true` to `b` (only the left-literal `true == b` folded
  before) — and the new `propagateKnownCondIntoBranches` rule propagates a
  variable condition's known value into its branches: inside `if c then t else
  e` the variable `c` is `true` throughout `t` and `false` throughout `e`, so
  its occurrences there are replaced with the matching literal and the existing
  folds collapse the re-test, dropping the unreachable default. The `elseif
  false ==` idiom disappears from every golden that carried it, and the
  collapsed `show` bodies now clear the call-site inline budget — in the
  `NumberIsNaN` golden that cascade dead-codes the whole `Ring` dictionary. A
  genuinely partial match keeps its default: only a re-test of the same
  variable folds. Eval goldens are unchanged.
