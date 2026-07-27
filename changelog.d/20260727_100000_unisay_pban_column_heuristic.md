### Changed

- Case expressions choose the next column to test by Maranget's `pbaN`
  composite ("Compiling Pattern Matching to Good Decision Trees"): the column
  needed by the longest prefix of remaining clauses wins, ties fall to the
  column with the fewest distinct patterns, then the fewest exposed sub-tests,
  then the leftmost. The previous single metric — the column tested by the
  most other clauses — could re-test a wide column inside every branch of a
  narrow one, emitting a larger decision tree (#237).
