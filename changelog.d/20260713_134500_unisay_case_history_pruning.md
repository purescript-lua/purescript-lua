### Changed

- The case decision-tree compiler's match-history pruning now covers every
  test, not only constructor tags: literal equality (integer, float, string,
  char, boolean) and array-length tests consult the history before being
  emitted, and the history accumulates every recorded outcome per scrutinee
  instead of keeping a single most-recent slot. A test whose outcome is
  already decided on the current path — repeated, or excluded by a mutually
  exclusive sibling that passed — is pruned instead of re-emitted, removing
  redundant retests and their dead branches (e.g. the nested `0 == v` retest
  in `Data.String.CodePoints.codePointAt`) (#184).
