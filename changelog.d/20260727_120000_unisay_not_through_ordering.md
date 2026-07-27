### Added

- The IR optimizer pushes logical `not` through an ordering comparison to
  its complement — `not (a < b)` becomes `a >= b`, and likewise for `<=`,
  `>`, `>=` (#238). The flip is exact only over a domain Lua orders totally,
  so it is gated on a literal operand of a NaN-free kind (`Int`, `Char`, or
  `String`); a `Float` literal is no witness, because the other operand can
  be NaN at runtime, where PureScript's `>=` on `Number` (true, via
  `compare NaN b = GT`) disagrees with Lua's raw `>=` (false). The dominant
  beneficiary is the residual a `>` comparison leaves once its `Ordering`
  decision tree folds: `not(n < 0) and n ~= 0` now emits as
  `n >= 0 and n ~= 0`. The other half of #238, fusing one-armed boolean
  conditionals into `and`/`or`, already ships since #203.
