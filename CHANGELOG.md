# Changelog

All notable changes to `pslua` (the PureScript-to-Lua compiler) are recorded
here. The format is based on [Keep a Changelog][keepachangelog], and the
project follows the [Package Versioning Policy (PVP)][pvp].

New entries are assembled from fragments in `changelog.d/` with
[scriv][scriv] on each release.

<!-- scriv-insert-here -->

## 0.3.0.0 - 2026-06-25

### Added

- `pslua` is now a first-class [Spago][spago] backend. With
  `workspace.backend.cmd: pslua` in `spago.yaml`, `spago build` links the
  project to Lua, and a new `--run <Module>.<entry>` flag lets `spago run` and
  `spago test` compile an entry point, execute it with `lua`, and forward the
  interpreter's exit code (#117).
- Projects consume the published [Lua package set][pkgset] through
  `workspace.packageSet.url` in `spago.yaml`: the PureScript Registry baseline
  with the Lua FFI forks overlaid.

### Changed

- Migrated the toolchain to the current Spago (`spago.yaml` + `spago.lock` and
  the PureScript Registry), replacing the Dhall-based configuration (#55).
- Deeply nested `Effect`/`ST` do-blocks (magic-do) and other deep monadic
  spines are flattened so the generated Lua stays under the interpreter's
  syntactic nesting limit (#46, #104, #108).
- The Nix toolchain moved to [purescript-overlay][overlay] for a pinned `purs`
  0.15.16 and Spago 1.0.4 (#54).

### Fixed

- De Bruijn indices are lowered correctly when a binder is removed, closing a
  class of silent miscompilations (#56).
- Eta reduction no longer rewrites programs unsoundly (#32); `shift`,
  `substitute`, and free-reference counting now respect sequential `Let`
  scoping (#37).
- Array-literal pattern binders read 1-based Lua indices instead of 0-based
  (#49).
- `Char` literals are escaped correctly, and table literals are parenthesised
  before they are indexed.
- The parent directory of `--lua-output-file` is created when it is missing
  (#61).

## 0.2 - 2024-04-21

### Changed

- Added inline-annotation support and reorganised the golden test suite.
- Removed `Prim.undefined` and stopped emitting unused function arguments.

### Fixed

- Foreign-expression precedence, foreign-header parsing, and `PSString`
  escaping when used as an object property.
- Pattern matching on qualified constructors.

## 0.1.2-alpha - 2023-07-17

### Added

- Support for polymorphic record updates.

## 0.1.1-alpha - 2023-07-15

### Changed

- Build and release workflow adjustments.

## 0.1.0-alpha - 2023-07-06

### Added

- Initial alpha release of the PureScript-to-Lua compiler backend: CoreFn to
  Lua compilation, FFI with Lua, dead code elimination, inlining, and bundling
  into a Lua module or a standalone application.

<!-- scriv-end-here -->

[keepachangelog]: https://keepachangelog.com/en/1.1.0/
[pvp]: https://pvp.haskell.org/
[scriv]: https://scriv.readthedocs.io/
[spago]: https://github.com/purescript/spago
[pkgset]: https://github.com/purescript-lua/purescript-lua-package-sets
[overlay]: https://github.com/thomashoneyman/purescript-overlay
