### Fixed

- The top-level inliner keeps a bare-`Ref` alias to an `@inline always`
  binding as the single materialization point instead of dissolving it:
  substituting the alias multiplied the target's use sites right before
  `Always` pasted its body into every one of them, duplicating the body
  (a lifted foreign's lambda, for example) across all alias use sites.
  The `Always` directive is now consulted by name at the top level, and
  a whole-binding paste spends the root annotation instead of letting it
  ride into the host binding, so an annotation no longer carries any
  directive weight once optimization starts rewriting the tree.
  `shareForeignAccessors` reads its `@inline always` opt-out from the
  same name-keyed policy rather than from surviving node annotations
  (#171).
