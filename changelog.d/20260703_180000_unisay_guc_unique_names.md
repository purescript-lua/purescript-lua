### Changed

- Local names in the IR pipeline follow the global-uniqueness condition
  (GUC): a `uniquify` entry pass makes every local binder unique within
  its top-level binding, and all later passes keep it that way
  (term-duplicating rewrites freshen the binders of each inserted
  copy). A local reference resolves to its binder by name alone: the
  per-name De Bruijn index is gone from the IR `Ref` node, along with
  the per-pass index arithmetic (`shift`/`unshift`, capture-avoiding
  substitution, index-keyed DCE scopes) that caused issues #37, #56,
  #133 and #134. Generated Lua changes only in the choice of local
  variable names; behaviour is unchanged (#139).

- The `--lint-ir` flag (and the always-on test-suite checks) verify the
  new `UniqueBinders` invariant at every pass boundary in addition to
  well-scopedness (#139).
