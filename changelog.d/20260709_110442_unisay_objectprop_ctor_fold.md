### Added

- Fold `ObjectProp` field reads over a known constructor in the IR optimizer
  (#213): `ObjectProp (K a₁ … aₙ) "valueᵢ"` over a saturated constructor
  application reduces to `aᵢ`. This is the record-projection form the pattern
  matcher actually emits — the `reduceObjectProp` twin (#153) for algebraic
  data and the companion of the `DataArgumentByIndex` field-read fold (#177),
  which covers only the index-read form. The label maps to its position through
  the constructor's declared field names (`value0`, `value1`, … — the row keys
  the Lua backend gives a `Ctor`), so a projection whose label is not one of
  them is declined. Discarded arguments are dropped, not evaluated or
  duplicated, and the folded value takes the read node's own annotation, not
  the field's (the leak care of `reduceObjectProp`). Standalone impact is near
  zero — the shape appears once dictionary-method inlining (#180) folds a
  constructor into a projection — so this lands as the enabler that issue
  builds on.
