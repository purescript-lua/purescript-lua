### Changed

- The IR constant folder now evaluates ordering comparisons (`<`, `<=`,
  `>`, `>=`) on two ASCII `Char` literals (#222). Equality on `Char`
  literals already folded; ordering was held back because Lua orders
  strings by bytes, which can disagree with codepoint order — but for
  two codepoints below U+0080 the single-byte representation orders
  identically, so the fold is gated on the ASCII range. Non-ASCII chars
  and `String` literals remain unfolded. In the `CharLiterals` golden,
  `show ('\t' < '\n')` collapses from a runtime branch on a constant
  condition to the literal `"true"`.
