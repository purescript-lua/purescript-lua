### Changed

- Call-site inlining growth is now bounded per expression (#221): the
  rewrite sweep that pastes worker and dictionary-method bodies is
  speculative — its result is kept only while the expression stays within
  a growth allowance (a quarter of its size, floored at the small-inline
  budget), and a sweep that grew without collapsing is redone with only
  directive-forced pastes armed. Product-monad chains, whose pastes meet
  no constructor fold, keep their compact shared calls instead of
  unrolling: the transformer-stack golden (`LongStackBind`) shrinks by
  ~300 lines back to its pre-inliner size, and a dozen more goldens lose
  paste residue. Explicit `@inline` directives keep their budget bypass
  inside vetoed expressions, and collapsing sum-type chains
  (Maybe/Either) are unaffected.
