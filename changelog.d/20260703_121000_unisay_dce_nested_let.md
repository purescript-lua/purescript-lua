### Fixed

- IR dead code elimination missed dead bindings of a `Let` that another,
  fully dead `Let` collapsed into: the dead binding was kept while the
  parameters of lambdas inside it were blanked, leaving unbound references
  in the intermediate IR. The next optimizer iteration masked the damage,
  so generated code was unaffected; the invariant checks introduced for
  #138 surfaced the bug on the golden corpus.
