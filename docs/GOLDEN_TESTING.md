# Golden testing in pslua

Golden tests are the primary **integration** test for the compiler: they take a
real PureScript module, run it through the whole pipeline, and pin the results
(the IR, the generated Lua, and — when the module is runnable — its actual
output) against checked-in expected files. A change anywhere in the pipeline
shows up as a diff in these files.

- Harness: `test/Language/PureScript/Backend/Lua/Golden/Spec.hs`
- Golden primitive (vendored, customised): `test/Test/Hspec/Golden.hs`
- Test modules: `test/ps/golden/Golden/<Name>/Test.purs`
- Generated artifacts: `test/ps/output/Golden.<Name>.Test/`
- Reset script: `scripts/golden_reset`

## The artifacts

Each test module `Golden.<Name>.Test` maps to a directory
`test/ps/output/Golden.<Name>.Test/`:

| File | Committed? | What it is |
|---|---|---|
| `corefn.json` | yes | CoreFn emitted by `purs` (`spago build -g corefn`). Its `builtWith` stamp tracks the `purs` version. |
| `golden.ir` | yes | Pretty-printed IR `UberModule` — **structural**, a pure function of the code. |
| `golden.lua` | yes | Generated Lua — **structural**. |
| `eval/golden.txt` | yes | Program stdout, normalised. The **semantic oracle** — hand-verified. Present only for runnable modules. |
| `actual.ir` / `actual.lua` / `eval/actual.txt` | no (git-ignored) | What the current run produced; written on every run for diffing. |
| `externs.cbor` | no (git-ignored) | `purs` build artifact. |

A module is treated as an **application** (entry `main` is called) when
`eval/golden.txt` exists, and as a **module** otherwise. That is the only thing
the eval file's presence controls, beyond enabling the eval check.

## What a run does

`cabal test spec` (matched by `-m Goldens`) runs four groups, in order:

1. **compile** (`beforeAll_ compilePs`) — `spago build -u '-g corefn'` in
   `test/ps`, producing `corefn.json` for every module.
2. **`compiles corefn files to lua`** — for each module:
   - `compileCorefn` reads CoreFn → builds the IR `UberModule` → compares the
     pretty-printed IR against `golden.ir`.
   - `compileIr` lowers IR → Lua → compares against `golden.lua`.
3. **`golden files should evaluate`** — for each `eval/golden.txt`: runs
   `lua <golden.lua>`, asserts exit 0, normalises stdout (strip/trim/drop blank
   lines), and compares against `eval/golden.txt`.
4. **`golden files should typecheck`** — runs `luacheck --quiet --std min` over
   the generated `golden.lua` files.

> **Important — the harness re-implements the pipeline.** `compileCorefn`
> (Spec.hs) calls `Linker.makeUberModule >>> optimizedUberModule` and
> `compileIr` calls `Lua.fromUberModule >>> optimizeChunk` **directly** — they
> do *not* go through `Backend.compileModules`. So any new IR pipeline pass must
> live inside `optimizedUberModule` (the shared function), or the golden tests
> will silently bypass it — a pass wired only into `Backend.compileModules`
> would run in a real build but stay invisible to these tests.

## The eval golden is the semantic oracle

`golden.ir` and `golden.lua` are *derived*: regenerating them from the current
compiler is always "correct" by construction. `eval/golden.txt` is different —
it is the **hand-verified expected behaviour**. A passing eval test is the only
thing that proves a codegen change preserved semantics; a luacheck pass alone
does not (it only checks the Lua parses/lints).

Therefore: **never regenerate `eval/golden.txt` from the compiler's current
output unless the program's behaviour legitimately changed and you have
re-verified it by hand.** Doing so silently bakes a regression in as the new
"expected" value.

## Updating goldens

### After a codegen/optimizer change (output moved, behaviour unchanged)

Accept the **structural** goldens in place; the eval oracle is left untouched:

```bash
PSLUA_GOLDEN_ACCEPT=1 cabal test spec
```

`PSLUA_GOLDEN_ACCEPT` rewrites a mismatching golden with the actual output and
passes — but **only** for goldens marked `acceptable` (`golden.ir` /
`golden.lua`, built with `acceptableGolden`). `eval/golden.txt` is built with
`defaultGolden` (`acceptable = False`) and is **never** auto-accepted, so it
keeps failing until you fix the regression or update it deliberately. Review the
resulting `git diff` before committing.

This replaces deleting goldens by hand. The equivalent manual workflow:

```bash
find test/ps/output -name golden.ir  -delete
find test/ps/output -name golden.lua -delete
cabal test spec            # recreates ir/lua; eval runs against the preserved oracle
```

### When the program output itself legitimately changed

Re-verify the new behaviour by hand, then update `eval/golden.txt` for the
affected module(s) explicitly (edit it, or delete just that file and let the run
recreate it after you've confirmed the program is correct).

### `scripts/golden_reset` — use with care

`golden_reset` deletes **every** file named `golden.*` in `test/ps/output`
(including `eval/golden.txt`) and reruns the suite to recreate them. Because it
nukes the oracle, only use it when the expected program output itself changed
across the board and you have re-verified it. For ordinary codegen churn, prefer
`PSLUA_GOLDEN_ACCEPT=1` above.

## Debugging a mismatch

- By default a mismatch prints a **bounded** summary: the first differing line
  plus a small window of each side, the line counts, and the path to the full
  `actual.*` file. This keeps a run with many mismatches cheap (it does not hold
  two full blobs and their diff per failure).
- For the **full** expected/actual diff: `PSLUA_GOLDEN_FULL_DIFF=1 cabal test spec`.
- The complete actual output is always on disk next to the golden
  (`actual.ir` / `actual.lua` / `eval/actual.txt`) for manual diffing.

The test runner's RTS is capped in `pslua.cabal`
(`-with-rtsopts=-N4 -c -M16g`): bounding the parallel-GC core count and heap
turns a pathological run (many large mismatches) into a clean heap-overflow
rather than an OOM that takes the machine down. The bounded summary above is the
other half of keeping failures affordable.

## Adding a new golden test

1. Create `test/ps/golden/Golden/<Name>/Test.purs` (module
   `Golden.<Name>.Test`). For a runnable test, give it `main :: Effect Unit`.
2. `cd test/ps && spago build -u '-g corefn' && cd ../..` to emit `corefn.json`.
3. For a runnable test, create the oracle by hand:
   `test/ps/output/Golden.<Name>.Test/eval/golden.txt` with the expected stdout,
   plus `eval/.gitignore` containing `actual.txt`.
4. Run `cabal test spec`. `golden.ir` / `golden.lua` are created on first run
   (they pass — "first time execution"); the eval test compares the program's
   output against your oracle.
5. Review the generated `golden.ir` / `golden.lua`, then commit `Test.purs`,
   `corefn.json`, `golden.ir`, `golden.lua`, `eval/golden.txt`, `eval/.gitignore`.
