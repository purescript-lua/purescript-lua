### Added

- Case-of-known-constructor folds in the IR optimizer (#177): a tag read over a
  saturated sum-type constructor application (`ReflectCtor (K a₁ … aₙ)`) folds
  to `K`'s tag string, and a field read (`DataArgumentByIndex i (K a₁ … aₙ)`)
  folds to `aᵢ` — the algebraic-type twin of the existing record-projection
  fold (`reduceObjectProp`). The tag fold then meets constant folding and the
  unreachable-branch rules, collapsing a decision tree over a known
  constructor to its live branch. Discarded arguments are dropped with the same
  discipline DCE applies to unused bindings (an unrun `Effect` thunk is never a
  casualty — an effect that must run is the kept field, not a dropped one). The
  fold fires only at exact saturation, so a partial application is left a
  function, and only sum types get the tag fold, since product constructors
  carry no tag row. Standalone impact is near zero — the shapes appear once
  dictionary specialization (#178/#180) inlines a constructor into a match — so
  this lands as the enabler those issues build on.
