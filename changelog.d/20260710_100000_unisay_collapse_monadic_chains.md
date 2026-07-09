### Changed

- Non-`Effect`/`ST` monadic chains now collapse to straight-line code (#180).
  After magic-do, a budgeted `specialize`+`dce` fixpoint inlines dictionary
  methods at their call sites so the case-of-known-constructor folds
  (#177/#213/#214) can fire, turning `Maybe`/`Either` `bind` cascades into
  straight-line code. Code growth is bounded by a size budget. Four cooperating
  parts:
    - `propagateKnownCtorThroughLet` resolves an imported constructor reference
      through the inline environment. A source-level `Right x` stays a reference
      to the `Data.Either.Right` worker (a bare `Ctor`, not a lambda, so the
      call-site inliner leaves it in place); without the resolution an inlined
      `bind`'s tag test never folds and the chain stayed a deeply-nested
      `if`/`let` tree that overflowed the Lua parser's nesting cap.
    - Magic-do effect runs carry a dedicated `EffectRunArg` marker, distinct
      from the `Prim.undefined` argument that forces an ordinary nullary thunk,
      so `isEffectRun` recognises exactly the effect runs magic-do introduces.
      Beta reduction then collapses the coincidentally nullary thunks (a
      superclass-dictionary accessor, a `runIdentity` newtype coercion) that a
      non-`Effect` monad such as `State` inlines, which were being left
      un-reduced and bloating the output.
    - A constructor-tag read distributes through a conditional of constructors,
      so an inlined comparison's `Ordering` if-tree folds to tag strings instead
      of allocating an `Ordering` table at runtime only to read the tag back.
