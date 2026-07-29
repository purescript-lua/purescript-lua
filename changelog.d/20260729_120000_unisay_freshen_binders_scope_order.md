### Fixed

- `freshenBinders` — the traversal that alpha-renames an expression's binders
  before a copy of it is pasted somewhere else — no longer renames a free
  reference that happens to share the name of a `Let` binder it does not sit
  under (#345). It collected every binder name of a `Let` into one rename map
  up front and walked all the right-hand sides under that map, so freshening
  `let x = x in y` renamed both the binder and the free `x` beside it, even
  though a `Standalone` binding is non-recursive and its right-hand side
  therefore resolves `x` to an outer binder
  (Note [Sequential scoping of Let bindings]):

  ```
  Let (Standalone (Name "x$0", Ref (Local (Name "x$0")))) (Ref (Local (Name "y")))
  ```

  The map is now threaded through the groupings in scope order — a
  `Standalone` right-hand side is renamed before its own binder enters, a
  `RecursiveGroup`'s members all enter before any of theirs is walked — which
  is what `alphaEq` and `countFreeRefs` already implement, and what the
  `LetValues` case of this same traversal already did:

  ```
  Let (Standalone (Name "x$0", Ref (Local (Name "x")))) (Ref (Local (Name "y")))
  ```

  Emitted code is unchanged, and the whole golden corpus stays byte-identical:
  `uniquifyNames` is the pipeline's entry pass and every later pass requires
  the global-uniqueness condition it establishes, so real compilation never
  presents a shadowed shape to `freshenBinders`. What the bug did cost was a
  test suite that reddened intermittently, because the property
  `IR Optimizer / inlines expressions referenced once` feeds the optimizer
  deliberately non-uniquified generated terms and occasionally drew the
  degenerate shape.
