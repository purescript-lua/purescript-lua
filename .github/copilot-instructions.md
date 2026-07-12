# Copilot Instructions for purescript-lua

`pslua` is a PureScript-to-Lua compiler backend. It reads PureScript CoreFn
(the compiler's intermediate representation) and emits Lua 5.1 code. This
document gives a Copilot cloud agent the context needed to work effectively in
this repository.

---

## Environment — Nix is mandatory

All builds and tests run inside `nix develop`. The system GHC is not used.

```bash
nix develop --command cabal build
nix develop --command cabal test all --test-show-details=direct
```

The flake is pinned:
- **GHC 9.8.x** (`compiler-nix-name = "ghc98"` in `flake.nix`)
- **PureScript 0.15.16** (`purs-bin.purs-0_15_16`)
- **Spago 1.0.4** (`spago-bin.spago-1_0_4`)
- **Lua 5.1** (`lua51Packages.lua`, `lua51Packages.luacheck`)

A Cachix binary cache (`purescript-lua`) is available so `nix develop` is fast
after the first run. The CI workflow (`ci.yaml`) shows the exact invocations.

---

## Repository layout

```
lib/       — Haskell library (the compiler)
exe/       — pslua executable (CLI in Cli.hs, entry in Main.hs)
test/      — Haskell test suite
test/ps/   — PureScript golden-test project (spago.yaml, src/, output/)
docs/      — GOLDEN_TESTING.md, QUIRKS.md, VERSIONING.md
scripts/   — golden_reset, prepare_release
changelog.d/ — scriv changelog fragments
```

Inside `lib/Language/PureScript/`:

```
CoreFn.*          — reads and parses CoreFn JSON from purs
Backend/IR.*      — intermediate representation, DCE, inliner, linker, optimizer
Backend/Lua.*     — Lua AST, codegen, printer, Lua-level optimizer, FFI linker
Backend.hs        — top-level compileModules orchestrator
```

---

## Build and test commands

```bash
# build
nix develop --command cabal build

# run all tests
nix develop --command cabal test all --test-show-details=direct

# run only the spec suite
nix develop --command cabal test spec

# format (Cabal/Nix/YAML via treefmt — does NOT touch Haskell)
nix develop --command nix fmt

# format Haskell (Fourmolu)
nix develop --command fourmolu -i lib/ exe/ test/

# lint Haskell
nix develop --command hlint lib/ exe/ test/

# run the compiled binary
nix develop --command cabal run pslua -- --help
```

---

## Haskell code style

- **Indentation**: 2 spaces (enforced by Fourmolu; see `fourmolu.yaml`)
- **Line length**: 80 characters maximum
- **Unicode syntax**: always use `∷` not `::`, `→` not `->`, `⇒` not `=>`
- **Prelude**: Relude (not base Prelude) — configured via cabal mixins in
  `pslua.cabal`; import base `Prelude` is hidden. Never import `Prelude` from
  base directly.
- **Imports**: qualified imports preferred; `ImportQualifiedPost` style
  (`import Foo qualified as F`)
- **Section headers**: use exactly 80-character comment lines:

  ```haskell
  --------------------------------------------------------------------------------
  -- Section Name ----------------------------------------------------------------
  ```

- All GHC extensions listed in `pslua.cabal`'s `default-extensions` stanza are
  available everywhere without pragma.
- GHC is set to `-Werror` for several warnings (`-Werror=missing-fields`,
  `-Werror=incomplete-patterns`, etc.) — fix all warnings, they are errors.

---

## Compilation pipeline

```
PureScript source
  ↓ (spago build with no-op backend)
CoreFn JSON  (test/ps/output/*/corefn.json)
  ↓ CoreFn.readModuleRecursively
CoreFn modules
  ↓ IR.mkModule
IR modules
  ↓ Linker.makeUberModule
UberModule
  ↓ optimizedUberModule   ← DCE, inliner, magic-do, flatten, rename
Optimized UberModule
  ↓ Lua.fromUberModule
Lua Chunk
  ↓ optimizeChunk
  ↓ exceedsNestingLimit (rejects if > 180 deep; throws Lua.NestingTooDeep)
Final Lua output
```

`compileModules` in `lib/Language/PureScript/Backend.hs` is the top-level
entry point that runs the full pipeline.

**Critical**: `optimizedUberModule` is the shared IR optimization function.
The golden test harness (`Golden/Spec.hs`) calls it directly — it does **not**
go through `compileModules`. Any new IR pass must be added inside
`optimizedUberModule`, otherwise it is silently skipped by golden tests.

---

## Testing

### Unit / property tests

Use Hedgehog (property-based). Generators are in
`test/Language/PureScript/Backend/IR/Gen.hs` and
`test/Language/PureScript/Backend/Lua/Gen.hs`.

### Golden tests

Golden tests are the primary integration tests. They:
1. Compile PureScript sources in `test/ps/` with spago → `corefn.json`
2. Run the IR pipeline → compare `golden.ir`
3. Generate Lua → compare `golden.lua`
4. (If `eval/golden.txt` exists) Execute with `lua`, compare stdout

**Important files per module** in `test/ps/output/Golden.<Name>.Test/`:

| File | Status | Role |
|---|---|---|
| `corefn.json` | committed | CoreFn from purs; `builtWith` tracks purs version |
| `golden.ir` | committed | Structural — auto-acceptable |
| `golden.lua` | committed | Structural — auto-acceptable |
| `eval/golden.txt` | committed | **Hand-verified semantic oracle — never auto-accept** |
| `actual.*` | git-ignored | Written on every run for debugging |

A module is compiled `AsApplication` (entry `main` called) when
`eval/golden.txt` exists; otherwise `AsModule`. The oracle must be created by
hand the first time.

**Accepting structural goldens after a codegen change:**

```bash
PSLUA_GOLDEN_ACCEPT=1 nix develop --command cabal test spec
```

This rewrites `golden.ir` and `golden.lua` but **never** touches
`eval/golden.txt`. Review `git diff` before committing.

**Full diff on mismatch:**

```bash
PSLUA_GOLDEN_FULL_DIFF=1 nix develop --command cabal test spec
```

**Adding a new golden test:**
1. Create `test/ps/src/Golden/<Name>/Test.purs` (module `Golden.<Name>.Test`)
2. `cd test/ps && spago build && cd ../..`
3. For a runnable test, create `test/ps/output/Golden.<Name>.Test/eval/golden.txt`
   (expected stdout) and `eval/.gitignore` (containing `actual.txt`) by hand
4. Run `cabal test spec` — `golden.ir`/`golden.lua` are created on first pass
5. Review and commit `Test.purs`, `corefn.json`, `golden.ir`, `golden.lua`,
   `eval/golden.txt`, `eval/.gitignore`

**Compiling PureScript sources** (required before golden tests):

```bash
cd test/ps && spago build && cd ../..
```

The `spago.yaml` uses a no-op `backend: cmd: "true"` so spago emits
`corefn.json` without invoking `pslua`.

---

## TDD workflow for bug fixes

1. Write a failing test that reproduces the bug (confirm it is **red**)
2. Apply the fix
3. Confirm the test goes **green**

Never write the fix before the test — a test written after cannot prove it
actually catches the bug.

---

## Versioning (PVP, not SemVer)

Version format: `A.B.C.D` (four components)
- `A.B` — major (breaking change)
- `C` — minor (backwards-compatible addition)
- `D` — patch (bug fix, internal refactor)

Three-component versions are wrong. The same string must appear in:
- `pslua.cabal` (`version:` field)
- git tag (no `v` prefix, e.g. `0.3.0.0`)
- GitHub release
- `CHANGELOG.md` section header

Changelog fragments go in `changelog.d/`. Collect with:
```bash
scriv collect --version <A.B.C.D>
```

---

## Lua target constraints

`pslua` targets **Lua 5.1 only**. FFI must be compatible with 5.1.

Key PureScript → Lua mappings:

| PureScript | Lua |
|---|---|
| `Int`, `Number` | `number` (doubles in 5.1) |
| `String`, `Char` | `string` (byte string) |
| `Boolean` | `boolean` |
| `Array a` | table, **1-indexed** |
| `{ a, b }` | table keyed by field name |
| `Unit` | `{}` — **never `nil`** |
| `a -> b -> c` | curried: `f(a)(b)` |
| `Effect a` | nullary thunk `function() … end` |

**`Unit` must be `{}`, never `nil`** — Lua tables silently drop `nil` values,
which collapses `Array Unit` to an empty table.

**Lua 5.1 limits** to keep in mind:
- Max ~200 local variables per function
- Max ~60 upvalues per closure
- Parser nesting depth limit ~200 levels in Lua; `pslua` rejects
  conservatively at depth 180 with the `NestingTooDeep` error

---

## FFI foreign module shape

Foreign `.lua` files are ordinary Lua 5.1 modules, parsed with the compiler's
own Lua 5.1 parser: a header of `local` helpers followed by a single returned
table of exports. Values need no special wrapping, and comments are allowed
anywhere, including between table fields:

```lua
local function helper(x) return x + 1 end

return {
  foo = function(a) return helper(a) end,
  -- comments between fields are fine
  bar = function(a) return function(b) return a + b end end,
}
```

---

## Common pitfalls

- **Golden pipeline bypass**: New IR passes wired only into `compileModules`
  are invisible to golden tests. Always put them in `optimizedUberModule`.
- **`eval/golden.txt` oracle**: Never regenerate it from current output unless
  you have re-verified the expected behaviour by hand.
- **`scripts/golden_reset`**: Deletes *all* `golden.*` files including
  `eval/golden.txt`. Prefer `PSLUA_GOLDEN_ACCEPT=1` for codegen churn.
- **Relude**: `fromList`, `toList`, `show`, etc. come from Relude. If
  something is missing, check Relude docs before importing from base.
- **`-Werror` warnings**: GHC treats several warning classes as errors.
  Fix all warnings before expecting a clean build.
- **`spago build` before golden tests**: `corefn.json` files must be up to
  date. Run `cd test/ps && spago build` after touching any `.purs` in
  `test/ps/src/`.
- **Lua 5.1 `unit`**: Requires `purescript-lua-prelude` ≥ v7.2.0 where
  `unit = {}`. If eval goldens print `0` for unit arrays, the prelude was
  downgraded — do not accept such goldens.
