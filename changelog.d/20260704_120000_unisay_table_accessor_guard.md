### Fixed

- The Lua optimizer rule that folds a field access into a table literal
  (`{ foo = 1 }.foo` to `1`) now declines when the constructor has a
  string-keyed row or a repeated field name, instead of silently folding to
  `nil` or to the wrong (first) value. Neither shape is emitted by the
  current codegen, so this closes a latent miscompile rather than a live one
  (#140).
