# Benchmark harness

Measures the performance of generated Lua and meters how LuaJIT's tracing
JIT treats it. Two kinds of output with two different purposes:

- **Wall-clock timings** (`./bench/run`) — local numbers for defending an
  optimization win. Too noisy for CI.
- **Deterministic LuaJIT counters** (`./bench/ci`) — byte-stable reports
  that CI diffs against the committed oracles in `goldens/`, so a codegen
  change that adds closure allocations or blacklists a loop shows up as a
  reviewable diff.

## Layout

- `micro/` — hand-written Lua pairs: the shape the backend currently
  generates for a pattern (`current`) next to the idiomatic Lua it stands
  for (`ideal`). These are fixed reference points; they do not change when
  codegen changes.
- `macro/` — specs driving real linked modules. Each spec names a `Bench.*`
  PureScript module (sources in `test/ps/src/Bench/`, linked by
  `./bench/link` into `_build/`), how to drive its export hot, and an
  `ideal` hand-written equivalent.
- `tools/` — the runners and meters. `fnew_census.lua` and
  `trace_report.lua` require LuaJIT (`jit.util`, `jit.attach`); the timing
  runners work under both PUC Lua and LuaJIT.
- `goldens/` — committed counter reports; the CI oracle.

## Usage

```bash
./bench/run                 # all wall-clock benchmarks, all runtimes
lua bench/tools/run_micro.lua bench/micro/curried_apply.lua        # one bench
luajit bench/tools/run_macro.lua bench/macro/array_foldl.lua 5e6   # custom n
./bench/ci                  # regenerate counters, verify against goldens/
./bench/ci --accept         # rewrite goldens/ after a deliberate change
```

Timings use `os.clock()` — CPU time, not wall time. That is deliberate:
the benchmarks are pure computation, and CPU time ignores scheduler noise.
It would under-report I/O, so do not reuse the timing helpers for anything
that waits. For quieter numbers, pin the process to a core (`taskset -c N
./bench/run`) and use the `performance` CPU governor; leave ASLR alone —
disabling it trades a real security property for nearly nothing.

## What the counters mean

`fnew_census` statically counts `FNEW` bytecodes (closure creation) in a
linked artifact without running it, split by where the instruction lives:
the **main chunk** runs once at load time, so its FNEWs are init cost; a
**function body** runs per call, so its FNEWs are steady-state allocation —
and each one aborts LuaJIT trace recording (`NYI: bytecode FNEW`), which is
what keeps curried hot code interpreted. The census is a pure function of
the artifact, hence byte-stable.

`trace_report` runs a macro spec hot and reports (a) the *set* of distinct
trace-abort sites with reasons and (b) the end state of loop and
function-entry bytecodes: LuaJIT rewrites an opcode to its `J*` form when
it installs a trace there and to its `I*` form when it blacklists the spot.
Raw abort *counts* are not reported: the retry-penalty step that leads to a
blacklist draws on an entropy-seeded PRNG, so counts jitter across runs
while the final opcode state and the abort-site set do not. Blacklisting is
never logged by `-jv`/`-jdump`; the post-hoc opcode read is the only stable
way to observe it.

Both reports record the LuaJIT version (`runtime:` header line): the abort
reasons, the NYI set, and the opcode families are properties of a specific
LuaJIT snapshot, so a toolchain bump that moves the counters shows up in
the golden diff as an attributable header change, not a mystery regression.

Two caveats about golden stability. The trace reports pin source *lines* of
both the linked artifact and the macro spec file itself, so any edit to
`bench/macro/*.lua` — comments included — legitimately moves the goldens;
rerun `./bench/ci --accept` and review the diff. And one residual
nondeterminism channel exists: LuaJIT's hot-counters live in a small hashed
table keyed by bytecode address, so a rare cross-process aliasing change
can alter trace formation order. `./bench/ci` generates every report twice
and compares, precisely so that this manifests as a distinct "reports
differ between runs" failure rather than a confusing golden mismatch.
