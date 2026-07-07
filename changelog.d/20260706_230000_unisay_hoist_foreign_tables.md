### Fixed

- Foreign module tables are no longer inlined into their use site. A foreign
  module referenced by exactly one surviving export was pasted into that site
  by the used-once heuristic; when the site sat under a lambda, the pasted
  table constructor re-evaluated per call, so an FFI value with identity
  (e.g. the prelude's `unit = {}`) came out as a fresh table on every
  evaluation instead of a shared singleton. The `ForeignImport` expression is
  now excluded from top-level inlining: the table stays hoisted as one shared
  binding and the accessor wrappers keep folding into field reads off it
  (#175).
