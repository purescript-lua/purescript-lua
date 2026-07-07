# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `pslua` - a PureScript to Lua compiler backend. It takes PureScript CoreFn (the PureScript compiler's intermediate representation) and compiles it to Lua. The project supports dead code elimination (DCE), code inlining, FFI with Lua, and can emit either Lua modules or standalone applications.

## Build System & Commands

The project uses **Nix with flakes** for reproducible builds and **Cabal** for Haskell development.

### Toolchain

Versions are pinned by the flake (`compiler-nix-name` and the
`purs-bin.*` / `spago-bin.*` attrs in `flake.nix`); update them there, not
locally:

- **GHC**: 9.8.x (haskell.nix `ghc98`)
- **PureScript**: `purs` 0.15.16, from [purescript-overlay] pinned as
  `purs-bin.purs-0_15_16` (explicit pin so `nix flake update` never silently
  bumps the compiler and churns goldens)
- **Spago**: 1.0.x — the new PureScript spago, driven by `spago.yaml` +
  `spago.lock` and the PureScript Registry (it dropped Dhall support), pinned
  as `spago-bin.spago-1_0_4`. The test project (`test/ps`) consumes the
  published purescript-lua package set via `workspace.packageSet.url` (see
  "Toolchain / package set" under Testing). The overlay's plain
  `spago` attr also resolves to 1.x; the explicit pin keeps the version
  changed only by a deliberate flake edit.

[purescript-overlay]: https://github.com/thomashoneyman/purescript-overlay

### Development Environment

```bash
# Enter development shell (provides all tools)
nix develop

# Or use direnv (if configured)
direnv allow
```

### Building

```bash
# Build the project
cabal build

# Build specific component
cabal build exe:pslua
cabal build lib:pslua
```

### Testing

```bash
# Run all tests with detailed output
cabal test all --test-show-details=direct

# Run specific test suite
cabal test spec

# Run tests in watch mode (requires ghcid)
ghcid --command="cabal repl test:spec" --test=":main"
```

The test suite includes:
- **Unit tests**: Property-based testing with Hedgehog
- **Golden tests**: Compiles PureScript test modules from `test/ps/src/Golden/*/Test.purs` to Lua and compares against golden files
- **Evaluation tests**: Runs generated Lua code and verifies output
- **Luacheck tests**: Validates generated Lua code syntax
- **Differential tests**: Anchors the Lua printer/parser pair to the reference
  implementation (`Differential.Spec` via `Test.Lua`): `luac -p` must accept
  everything the printer emits, and a semantic differential evaluates the
  printer's precedence/associativity against the `lua` interpreter itself

### Testing PureScript Code

Golden tests require compiling PureScript sources first:

```bash
# Compile PureScript test sources (from test/ps directory)
cd test/ps
spago build
cd ../..
```

The new spago manages codegen itself and rejects `--codegen` in `--purs-args`.
CoreFn is emitted because `test/ps/spago.yaml` declares a no-op `backend`
(`cmd: "true"`): with a backend configured spago compiles with `--codegen
corefn` and the harness reads the resulting `output/**/corefn.json`. The
golden sources live under `test/ps/src/` (new spago only globs `src/` and
`test/`), with `.lua` FFI files co-located next to each `.purs`.

### Regenerating Golden Files

When a deliberate codegen/optimizer change legitimately moves the output, accept
the new structural goldens in place:

```bash
# Rewrites mismatching golden.ir / golden.lua with the actual output and passes
PSLUA_GOLDEN_ACCEPT=1 cabal test all --test-show-details=direct
```

Only the *structural* goldens (`golden.ir`, `golden.lua`) are auto-accepted. The
hand-verified `eval/golden.txt` oracle is **never** auto-accepted — if a change
alters runtime output, those tests still fail, which is the semantic safety net.
Review the resulting `git diff`, then run `cabal test` once more (no env var) to
confirm the accepted state is stable.

NB: `./scripts/golden_reset` deletes **all** `golden.*` files — including
`eval/golden.txt` — and lets the harness recreate them from current output. That
silently overwrites the hand-verified oracle with whatever the code emits now
(even if buggy), so prefer `PSLUA_GOLDEN_ACCEPT` and do not run `golden_reset`
unless you intend to discard the oracles.

### Code Formatting & Linting

```bash
# Format Cabal/Nix/YAML/Dhall via treefmt
nix fmt

# Haskell is formatted separately with Fourmolu (NOT part of `nix fmt`)
fourmolu -i lib/ exe/ test/

# Run HLint
hlint lib/ exe/ test/

# Check Lua files
luacheck --quiet --std min test/ps/output/
```

### Running the Compiler

```bash
# Build and run
cabal run pslua -- --help

# Or after building (resolves the dist-newstyle path for the current GHC)
$(cabal list-bin pslua) --help

# Or via nix
nix run . -- --help
```

Typical usage:
```bash
pslua \
  --foreign-path ./foreign \
  --ps-output ./output \
  --lua-output-file ./dist/Main.lua \
  --entry Main.main
```

`pslua` is also a first-class Spago backend (`workspace.backend.cmd: pslua` in
`spago.yaml`). Spago compiles to CoreFn and then runs the backend command, so
`spago build` links the project to Lua via the configured `--entry` /
`--lua-output-file`. For `spago run`, Spago invokes the backend a second time
as `pslua --run <Module>.<entry>` (without the build-phase args); `--run`
compiles that entry point, writes it to a temp file, executes it with `lua`,
and forwards lua's exit code (`Language.PureScript.Backend.Lua.Run.runChunk`).
Foreign `.lua` files are resolved next to each module's source (recorded in the
CoreFn `modulePath`), so dependency FFI in `.spago/**` is found automatically;
`--foreign-path` is only a secondary fallback.

## Code Architecture

### Compilation Pipeline

The compilation happens in several distinct phases:

```
PureScript Source → CoreFn → IR → Lua → Optimized Lua
```

1. **CoreFn Reading** (`Language.PureScript.CoreFn.*`)
   - Reads PureScript compiler's CoreFn JSON output
   - Parses module structure, imports, and expressions

2. **IR Translation** (`Language.PureScript.Backend.IR.*`)
   - Converts CoreFn to an intermediate representation (IR)
   - IR is simpler than CoreFn but still high-level
   - Handles data declarations, bindings, and module structure

3. **IR Optimization** (`Language.PureScript.Backend.IR.Optimizer`)
   - Performs optimizations on IR:
     - Eta reduction/expansion
     - Beta reduction
     - Constant folding
     - Case-of-case transformation
   - **Inliner** (`IR.Inliner`): Marks expressions for inlining
   - **Dead Code Elimination** (`IR.DCE`): Removes unused bindings
   - **Uncurrying** (`IR.Uncurry`): Splits curried bindings into n-ary
     workers plus curried wrappers and rewrites saturated call sites to
     direct worker calls

4. **Linking** (`Language.PureScript.Backend.IR.Linker`)
   - Creates an "UberModule" containing all reachable code
   - Supports two modes:
     - `LinkAsModule`: Creates a Lua module (returns a table)
     - `LinkAsApplication`: Creates a runnable Lua script (calls entry point)

5. **Lua Code Generation** (`Language.PureScript.Backend.Lua`)
   - Converts optimized IR to Lua AST
   - Handles foreign imports via FFI
   - Manages name mangling and scope

6. **Lua Optimization** (`Language.PureScript.Backend.Lua.Optimizer`)
   - Optimizes generated Lua code

7. **Lua Printing** (`Language.PureScript.Backend.Lua.Printer`)
   - Pretty-prints Lua AST to text

### Key Module Structure

**CoreFn Layer** (`Language.PureScript.CoreFn.*`):
- `CoreFn.Reader`: Reads CoreFn JSON from disk
- `CoreFn.FromJSON`: JSON deserialization
- `CoreFn.Expr`, `CoreFn.Module`, `CoreFn.Meta`: CoreFn data types
- `CoreFn.Traversals`: Traversal utilities
- `CoreFn.Laziness`: Lazy binding analysis

**IR Layer** (`Language.PureScript.Backend.IR.*`):
- `IR.Types`: Core IR data types (`RawExp`, `Module`, `Binding`)
- `IR.Names`: Name types (`Qualified`, `ModuleName`, etc.)
- `IR.Linker`: Creates UberModule from multiple modules
- `IR.Optimizer`: IR-level optimizations
- `IR.DCE`: Dead code elimination
- `IR.Inliner`: Inlining annotations and logic
- `IR.Query`: Queries over IR expressions

**Lua Backend** (`Language.PureScript.Backend.Lua.*`):
- `Lua.Types`: Lua AST types (`Chunk`, `Statement`, `Exp`), annotated with
  `Comments`
- `Lua.Name`: Safe Lua identifier generation
- `Lua.Parser`: Full Lua 5.1 parser producing the Lua AST (used for FFI files
  and runtime fixtures; preserves comments in annotation slots)
- `Lua.Printer`: Pretty-printing Lua code
- `Lua.Optimizer`: Lua-level optimizations
- `Lua.Linker.Foreign`: FFI support for Lua foreign modules (file resolution +
  foreign-module shape on top of `Lua.Parser`)
- `Lua.Fixture`: Runtime support code injected into output
- `Lua.Key`, `Lua.Traversal`: Table keys and AST traversal helpers

**Main Entry** (`Language.PureScript.Backend`):
- `compileModules`: Top-level compilation function orchestrating the pipeline

### Important Concepts

**De Bruijn Indices**: The IR uses De Bruijn indices for variable references. A `Ref` contains:
- A qualified name
- An index indicating which binding of that name to reference

**Groupings**: Bindings are wrapped in `Grouping`:
- `Standalone`: Non-recursive binding
- `RecursiveGroup`: Mutually recursive bindings

**AppOrModule**: Determines compilation mode:
- `AsModule ModuleName`: Generate a Lua module
- `AsApplication ModuleName Ident`: Generate an executable that calls the entry point

**UberModule**: A flattened representation of all modules after linking, containing:
- All reachable bindings
- Module exports
- Foreign imports

## Code Style

### Haskell Style

This project follows specific Haskell style conventions:

- **Indentation**: 2 spaces (enforced by Fourmolu)
- **Line length**: Max 80 characters
- **Unicode**: Always use unicode syntax (`∷` instead of `::`, `→` instead of `->`)
- **Prelude**: Uses Relude (not base Prelude)
- **Imports**: Explicit qualified imports preferred
- **Extensions**: Many enabled by default (see `pslua.cabal` common stanza)

### Formatting Configuration

- **Fourmolu** (`fourmolu.yaml`):
  - 2-space indentation
  - 80-character column limit
  - Leading commas and function arrows
  - Unicode always
  - Multi-line Haddock style

- **HLint** (`.hlint.yaml`):
  - Configured with project-specific extensions
  - Run with `--color --cpp-simple -XQuasiQuotes -XImportQualifiedPost`

### Section Comments

Use section-style comments to organize code:

```haskell
--------------------------------------------------------------------------------
-- Section Title ---------------------------------------------------------------

code here...
```

Both lines should be exactly 80 characters. Helper functions go at the bottom after a "Helper Functions" or "Utility Functions" section.

## Testing Strategy

### Golden Tests

Golden tests are the primary integration testing mechanism:

1. PureScript test files in `test/ps/src/Golden/*/Test.purs`
2. Compiled to CoreFn with `spago build` (the no-op `backend` in
   `test/ps/spago.yaml` is what makes spago emit CoreFn — see "Testing
   PureScript Code")
3. Test suite reads CoreFn, compiles to IR, generates Lua
4. Compares against golden files:
   - `golden.ir` - Intermediate representation
   - `golden.lua` - Generated Lua code
   - `eval/golden.txt` - Execution output (if module has a `main` function)

**The golden harness re-implements the IR pipeline.** `compileCorefn` in
`test/Language/PureScript/Backend/Lua/Golden/Spec.hs` calls
`makeUberModule >>> optimizedUberModule` directly — it does *not* go through
`Backend.compileModules`. Any new IR pipeline pass must live inside
`optimizedUberModule` (the shared function), or the golden tests will silently
bypass it.

To add a new golden test:
1. Create `test/ps/src/Golden/NewTest/Test.purs`
2. Run `cabal test` - it will fail and create `actual.*` files
3. Review the actual files
4. Rename `actual.*` to `golden.*` if correct
5. Commit the golden files

For a **runnable** module (one with `main`) whose execution output you want
checked, also create `eval/golden.txt` with the expected output (plus
`eval/.gitignore` containing `actual.txt`) **before** running. The presence of
`eval/golden.txt` is what makes the harness link the module `AsApplication` and
run it through `lua`; without it the module is linked `AsModule` and only the
`.ir`/`.lua` goldens are generated (no execution check).

### Property-Based Tests

The project uses Hedgehog for property-based testing:
- Generators in `test/Language/PureScript/Backend/IR/Gen.hs`
- Tests in `test/Language/PureScript/Backend/IR/Spec.hs` and similar

## Development Workflow

For a **bug fix**, work test-first (TDD): write a test that reproduces the bug
and confirm it is **red** *before* touching the fix, then apply the fix and
confirm it goes **green**. A fix written before its test cannot prove it
actually catches the bug. Size the coverage to the bug (one focused case is
often enough; add more when the bug spans several code paths).

1. Make code changes in `lib/` or `exe/`
2. Format code: `fourmolu -i lib/ exe/ test/`
3. Run HLint: `hlint lib/ exe/ test/`
4. Run tests: `cabal test all --test-show-details=direct`
5. If golden tests fail, inspect `actual.*` files in `test/ps/output/`
6. Update golden files if changes are correct

## Versioning and Releases

`pslua` follows the **Package Versioning Policy (PVP)**, not SemVer: versions
are four components `A.B.C.D` where `A.B` is the major version. The same string
is used everywhere — the `version:` field in `pslua.cabal`, the git tag (no `v`
prefix, e.g. `0.3.0.0`), the GitHub release, and the `CHANGELOG.md` section
header — and they must agree. A three-component version anywhere is a mistake to
fix, not a second convention. The changelog is managed with `scriv` (fragments
in `changelog.d/`, assembled by `scriv collect --version <A.B.C.D>` on release).

See `docs/VERSIONING.md` for the full policy, the meaning of each component, and
the release checklist.

## Updating Dependencies

1. `nix flake update` — refreshes haskell.nix (and with it the Hackage
   index pin), nixpkgs, and purescript-overlay. To bump GHC, `purs`, or
   spago, edit `compiler-nix-name` / `purs-bin.*` / `spago-bin.*` in
   `flake.nix` (the toolchain attrs are explicitly version-pinned, so a flake
   update alone never changes them).
2. PureScript dependencies live in `test/ps/spago.yaml`, which consumes the
   published Lua package set via `workspace.packageSet.url` (a
   `purescript-lua/purescript-lua-package-sets` `psc-*` release). That set is
   the upstream registry baseline with the Lua forks (`purescript-lua-*`, which
   ship `.lua` FFI) overlaid as git entries, so it overrides the
   JavaScript-targeting upstreams — no inlined `extraPackages`. To move the
   whole set, bump the `packageSet.url` tag (the fork versions / dependency
   lists are carried centrally in the set, sourced from the set repo's
   `src/packages.json`); `spago.lock` pins the resolved set (its URL plus an
   inlined snapshot) and the fork commits, and is committed. Keep `purs` at
   0.15.16: no registry set is built for
   0.15.16, so the set is built with 0.15.15 (a proven-compatible pairing).
3. After changing the `packageSet.url` tag or `purs`: `cd test/ps && spago
   build`, then `cabal test all`. Delete `spago.lock` first if you want spago to
   re-resolve the set.
4. Expected churn after updates:
   - `test/ps/output/Golden*/corefn.json` are committed; their `"builtWith"`
     stamp changes with the `purs` version, and `modulePath` reflects the
     `src/` source location.
   - `golden.ir` files embed `.spago/p/<pkg>/<commit-hash>/...` source paths
     (the new spago content-addressed layout), so a fork-tag bump that resolves
     to a new commit legitimately changes goldens. `golden.lua` is path-free,
     so it only moves when codegen genuinely changes.

### Known Pitfalls

See also `docs/QUIRKS.md` for the catalogue of compiler/Lua-target quirks
(parser nesting limit, `Char` byte-string shapes, Lua 5.1 floor, …).

- **`unit` must not be `nil`**: Lua tables cannot hold `nil` values, so
  `Array Unit` silently collapses to an empty table if the prelude defines
  `unit = nil`. Requires `purescript-lua/purescript-lua-prelude` ≥ v7.2.0, where
  `unit = {}`. If eval goldens for unit arrays start printing `0`, a
  package set downgraded the prelude — do not accept such goldens.
- A generated-Lua change that only passes `luacheck` is not verified:
  eval goldens (`eval/golden.txt`) are the semantic check.

## Debugging Tips

- The IR and Lua types have `Show` instances - use `pShowOpt` for pretty debug output
- Golden test failures show diffs between expected and actual
- Use `actual.*` files alongside `golden.*` files to debug compilation issues
- Check `test/ps/output/Golden.*/` directories for generated IR and Lua
- Lua evaluation errors are captured in the test output
