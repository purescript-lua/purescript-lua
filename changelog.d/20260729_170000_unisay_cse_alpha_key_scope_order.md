### Fixed

- `alphaKey` — the canonical form common-subexpression elimination groups
  repeated expressions by — no longer swallows a free reference that happens to
  share the name of a `Let` binder it does not sit under (#349). It collected
  every binder name of a `Let` into one rename map up front and canonicalized
  all the right-hand sides under that map, so `let x = x in x` and
  `let y = x in y` — alpha-equivalent, since a `Standalone` binding is
  non-recursive and its right-hand side therefore resolves `x` to an outer
  binder (Note [Sequential scoping of Let bindings]) — received different keys:

  ```
  alphaEq a b     = True
  alphaKey a == b = False
  keyA = Let () (Standalone ((),Name "$key0",Ref () (Local (Name "$key0"))) :| []) (Ref () (Local (Name "$key0")))
  keyB = Let () (Standalone ((),Name "$key0",Ref () (Local (Name "x"))) :| []) (Ref () (Local (Name "$key0")))
  ```

  The map is now threaded through the groupings in scope order — a `Standalone`
  right-hand side is canonicalized before its own binder enters, a
  `RecursiveGroup`'s members all enter before any of theirs is walked — the
  same shape `freshenBinders` and the `LetValues` case of this traversal
  already use, so the free `x` survives in both keys:

  ```
  alphaKey a == b = True
  keyA = Let () (Standalone ((),Name "$key0",Ref () (Local (Name "x"))) :| []) (Ref () (Local (Name "$key0")))
  keyB = Let () (Standalone ((),Name "$key0",Ref () (Local (Name "x"))) :| []) (Ref () (Local (Name "$key0")))
  ```

  Emitted code is unchanged and the golden corpus stays byte-identical: the bug
  could only ever cost a hoist (a shadowed right-hand side keyed to a shape
  correct canonicalization cannot emit, so two occurrences that mean different
  things could not merge), and it did not fire at all, because `uniquifyNames`
  is the pipeline's entry pass and CSE runs behind the global-uniqueness
  condition it establishes, under which no free reference can collide with a
  binder. What the fix buys is that `alphaKey` no longer depends on that
  condition for correct name resolution.
