### Added

- The IR optimizer folds `Record.Unsafe` surgery over statically-known
  records, through a small handwritten registry of foreign semantics
  complementary to the source-derived foreign lift: with a static label,
  `unsafeGet` becomes a direct field read (collapsing to the field's value on
  a manifest literal), and `unsafeSet`/`unsafeDelete`/`unsafeHas` on a
  manifest record literal fold into the resulting literal or boolean — one
  table allocation instead of two per folded copy. `Unsafe.Coerce.unsafeCoerce`
  joins the foreign-lift allowlist, so the identity coercion beta-reduces away
  at every applied site and its FFI table disappears from the output (#236).
