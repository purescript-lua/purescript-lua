### Added

- The compiler now ships a default `@inline` directive pack for the
  prelude/core forks (`Inliner.defaultDirectives`): class member accessors
  (`map`, `bind`, `append`, ...) at `arity=1`, the tiny dictionary-
  parameterized combinators (`bindFlipped`, `applySecond`, `composeKleisli`,
  ...), the function-instance dictionary methods
  (`semigroupFn.append arity=2`, `categoryFn.identity always`), the generics
  glue (`genericShow`/`genericEq`/`genericCompare`), and the ST/Ref `modify`
  wrappers. The pack is the lowest-precedence directive source: a consumer's
  `--directives` file or a library author's module-header pragma overrides
  any entry, and an explicit `default` mode masks one back to the built-in
  heuristics (#242).

### Changed

- Directive targets may now contain `_` and `'`, matching PureScript
  identifier syntax (previously `Effect.Ref.modify_` or a primed name could
  not be named by any pragma or directives file).
