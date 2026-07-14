### Changed

- Data constructor applications are uncurried (#201). The IR `Ctor` node now
  carries its field arguments directly — saturated by construction — and
  translation emits a constructor as a manifest curried lambda chain over it,
  the same shape a user-written curried function has, so the worker/wrapper
  split (#24) covers constructors with no special case. A saturated
  application of an arity-≥2 constructor compiles to one n-ary worker call
  (one call, one table build — previously a closure allocation and a call per
  field), a saturated arity-1 application inlines to a direct in-place table
  build with zero calls, and partial or higher-order uses keep going through
  the curried wrapper, unchanged. The case-of-known-constructor folds
  (#177/#180/#214/#232) recognise every post-uncurry shape of a constructor
  value — the in-place node, the n-ary worker call, the curried spine, and
  the wrapper-to-worker hop — so match-site collapsing keeps firing across
  the pipeline. Inlined sum-constructor sites each embed a copy of the tag
  string, so linked chunks with long constructor-heavy chains grow in size;
  hoisting shared tags is a potential follow-up.
