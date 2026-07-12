### Added

- Graduated `@inline` directives (#232). The pragma grammar grows from binary
  `always`/`never` to `[export] name[.label|...label]
  (default|never|always|arity=N)`: `arity=N` inlines a binding only at call
  sites applying at least N arguments (bypassing the size budget) and pins it
  as a shared reference elsewhere; the accessor forms attach a policy to one
  dictionary field (`.label`) or to a field of the record a binding returns
  (`...label`) instead of the whole record; `default` explicitly resets a
  target to the built-in heuristics. A new `--directives <file>` option
  supplies fully-qualified directives project-wide, layered by specificity: a
  local module-header pragma beats the file, which beats `@inline export`
  pragmas shipped by the defining module, which beat the heuristics. Unmatched
  file entries are ignored, so a shared file can cover optional dependencies.

- Constructor-eliminating reads now fold through a saturated application of a
  *reference* to a top-level constructor binding (`(Op f).value0` resolves to
  `f` without pasting the constructor), and projections sink through `let`
  bindings to meet the record they select from. Together these let a
  directive-driven paste collapse through the beta/case-of-known-constructor
  cascade; as a side effect the existing specialize pass folds deeper (the
  `LongReaderBind`/`LongWriterBind` goldens shrink, with unchanged runtime
  output).

### Fixed

- An `@inline` annotation on a binding whose right-hand side is a bare
  application, variable reference, or record update was silently dropped
  during translation, so pragmas like `@inline foo never` had no effect on
  point-free definitions. The annotation now lands on the binding root for
  those shapes too.
