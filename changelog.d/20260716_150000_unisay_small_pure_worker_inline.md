### Changed

- Small pure workers now dissolve into their saturated call sites (#211),
  generalizing the bare-primop unfolding of #281: a worker body that is a
  tree of primops, equality tests and negations over parameter references,
  scalar literals and cheap projection chains — possibly under a nested
  lambda — is pasted at every saturated n-ary call site, bounded by the
  small-inline budget. A shared helper such as `add3 x y z = x + y + z` or
  `first x _ = x` no longer costs a Lua call per use: sites fold to the
  inline expression and constant arguments fold further at compile time
  (`add3 1 2 3` emits `6`). Workers whose bodies apply a function, branch,
  or exceed the budget keep sharing, as do all value-position uses.
