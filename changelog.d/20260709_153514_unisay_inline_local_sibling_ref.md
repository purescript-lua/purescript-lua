### Fixed

- `inlineLocalBinding` no longer duplicates a local binding that a sibling `Let`
  grouping still references (#217). Its use-count looked at the `Let` body only,
  missing the RHSs of later groupings that sequential scoping lets name an
  earlier binder, so a non-trivial binding read once in the body and once in a
  sibling RHS was inlined into the body and its RHS evaluated twice. When the RHS
  performed an effect the effect was duplicated (for instance a `tailRecM` loop
  allocating two mutable Refs instead of one). The rule now declines to inline a
  non-trivial binding a sibling RHS references.
