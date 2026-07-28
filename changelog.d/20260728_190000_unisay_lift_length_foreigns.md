### Changed

- The foreign lifter now translates Lua's unary `#` operator, so the one-line
  `length` exports of the array and string forks —
  `function(xs) return #xs end` — lift into the IR instead of staying opaque.
  `Data.Array.length` and `Data.String.CodeUnits.length` join the lift
  allowlist, and a saturated site collapses to a bare `#xs`: the VM's own
  length opcode in place of a foreign-table read plus a call frame per use,
  which matters most where a length read sits in a loop guard. Both lifted
  rows also drop out of the emitted FFI tables, as the uncurried wrappers
  already did. A length read over a manifest array now meets the existing fold
  and becomes a constant. `Data.Array.ST.lengthImpl` stays off the allowlist
  despite the identical body: its call is an effect statement whose thunk
  codegen sheds only for a call body, so lifting it would buy a closure
  allocation on top of the call it replaced (#247).

- The IR node for Lua's `#` is named `PrimLen`, sitting alongside `PrimNot` as
  the second unary primop of `Note [IR primops]`, rather than `ArrayLength`.
  One node per Lua operator is what lets the length reads the lifter produces
  inherit every rewrite the array-pattern length test already had — the
  literal-array fold, the push into `if` branches, the CSE candidate class, the
  `Deref` inlining tier — instead of needing a twin of each. The new
  `Note [PrimLen reads immutable values]` records the invariant those licences
  rest on and why the mutable `STArray` length is kept out of the node.
