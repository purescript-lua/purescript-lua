### Fixed

- The top-level inliner keeps a bare-`Ref` alias to an `@inline always`
  binding as the single materialization point instead of dissolving it:
  substituting the alias multiplied the target's use sites right before
  `Always` pasted its body into every one of them, duplicating the body
  (a lifted foreign's lambda, for example) across all alias use sites.
  The `Always` directive is now also consulted by name at the top level,
  so a binding that merely received an always-annotated body during an
  earlier paste no longer turns unconditionally inlinable itself (#171).
