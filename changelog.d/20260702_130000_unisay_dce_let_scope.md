### Fixed

- IR dead code elimination handles `Let` bindings correctly. Dropping a dead
  binding did not lower the De Bruijn indices of references that skipped over
  it (the `Let` analogue of the #56 `Abs` fix), so the compiler either crashed
  with `UnexpectedRefBound` in the Lua code generator or silently resolved the
  reference to the wrong binder. The scope the `Let` body was resolved against
  was also built in reverse, so among same-name sibling bindings the body's
  index 0 picked the first binding instead of the last, contradicting
  Note [Sequential scoping of Let bindings] and marking the wrong binding
  live (#134).
