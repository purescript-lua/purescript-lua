### Added

- General case-of-case over an `IfThenElse` scrutinee in the IR optimizer
  (#243): an accessor or application applied to a conditional — a field,
  index, length, or tag read, or a call — distributes into both arms, so
  `(if p then a else b).f` becomes `if p then a.f else b.f` and
  `(if p then f else g) x` becomes `if p then f x else g x`. The conditional
  otherwise sits in expression position, an IIFE in the generated Lua, and
  the pushed operation never reaches the arms where the constructor,
  projection and beta folds fire. The arms are never duplicated; the only
  syntactically duplicated expressions are an application's arguments, gated
  on being trivial to re-emit, so a call whose argument does real work is
  left alone. Subsumes the fold-gated tag-read distribution (#180): a tag
  read now distributes over any conditional, folding in whichever arms turn
  out to be constructors. Eval outputs unchanged.
