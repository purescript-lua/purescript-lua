### Added

- The IR optimizer reassociates associative operator chains and coalesces
  their constants: all int literals of a `+`/`*` spine fold into one (so
  `1 + x + 2 + y + 3` becomes `x + y + 6`), and adjacent string literals of a
  `..` spine merge (`x <> "a" <> "b"` emits `x .. "ab"`, covering a resolved
  `Semigroup` `append`). Float chains are left alone — IEEE `+`/`*` are not
  associative — as are the short-circuiting `and`/`or`, and an int fold whose
  result would leave the exactly-representable ±2^53 range declines (#235).
