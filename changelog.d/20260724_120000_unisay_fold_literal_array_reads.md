### Added

- Array-length and indexing reads over manifest array literals fold at
  compile time (#225). A pattern match on a fixed-length array whose
  scrutinee is a literal array — `case [10, 20] of [a, b] → a + b; _ → -1`
  — compiled to a runtime length check and element reads (`if 2 == #(v)
  then return v[1] + v[2] else return -1 end`), although every part is
  statically known. Two additions reduce it. The new `reduceArrayRead`
  rule — the `reduceObjectProp` sibling for arrays — folds `arrayLength`
  over an in-place `LiteralArray` to the element count and an in-range
  `ArrayIndex` to the element itself. And the new
  `propagateKnownArrayThroughLet` rule — the literal-array sibling of the
  known-constructor propagation (#214) — carries a let-bound array literal
  into the binder's length and index reads, binding each read element once
  to a fresh element-binder so no element is duplicated or re-evaluated.
  The existing folds then finish the collapse (`2 == 2` to `true`,
  unreachable-else removal, constant arithmetic), leaving `30` for the
  shape above. The length folds against the IR element count, which is
  exact — a `LiteralArray` codegens to a hole-free positional table — so
  no reasoning about Lua's `#` over tables with holes is involved. A match
  on an array of unknown length is untouched, an out-of-range read
  declines, and a binder also read as a whole value keeps its binding.
  Eval goldens are unchanged.
