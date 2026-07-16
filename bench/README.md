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
- `tools/` — the runners and meters. `fnew_census.lua`, `tnew_census.lua`
  and `trace_report.lua` require LuaJIT (`jit.util`, `jit.attach`); the
  timing runners work under both PUC Lua and LuaJIT.
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

`tnew_census` is the same static walk for the two table-creation bytecodes
(`TNEW` allocates a fresh table, `TDUP` clones a constant template; a
codegen change can turn one into the other, so the per-site list names the
opcode). The main-chunk/function-body split means the same thing as for
FNEW. Unlike FNEW, neither opcode aborts trace recording — table
allocation cost is invisible to the trace report, which is why this census
exists: a function-body TNEW/TDUP is a table allocated on every call.

`trace_report` runs a macro spec hot under eager hot thresholds
(`hotloop=1`, see the tool header: eager firing removes the counter
warm-up during which per-process hash collisions can decay a counter
forever) and reports (a) the *set* of distinct trace-abort sites with
reasons and (b) the end state of loop and function-entry bytecodes:
LuaJIT rewrites an opcode to its `J*` form when it installs a trace there
and to its `I*` form when it blacklists the spot. Raw abort *counts* are
not reported: the retry-penalty step that leads to a blacklist draws on
an entropy-seeded PRNG, so counts jitter across runs while the abort-site
set and the opcode end state are far steadier. Steadier is not identical,
though — a residual spot can still resolve in one process and not the
next — so the report takes a majority vote over several independent
trials (see below). Blacklisting is never logged by `-jv`/`-jdump`; the
post-hoc opcode read is the only stable way to observe it.

Both reports record the LuaJIT version (`runtime:` header line): the abort
reasons, the NYI set, and the opcode families are properties of a specific
LuaJIT snapshot, so a toolchain bump that moves the counters shows up in
the golden diff as an attributable header change, not a mystery regression.

Two caveats about golden stability. The trace reports pin source *lines* of
both the linked artifact and the macro spec file itself, so any edit to
`bench/macro/*.lua` — comments included — legitimately moves the goldens;
rerun `./bench/ci --accept` and review the diff. And trace formation is not
deterministic per process: LuaJIT's hot-counters live in a small hashed
table keyed by bytecode address, and the retry penalty draws on an
entropy-seeded PRNG, so a spot on the hot-count boundary can form a trace in
one run and not the next. `trace_report.lua` absorbs this by taking a
majority vote over several independent trials: a marginal spot is reported
iff most processes form it, and the misreport odds decay binomially in the
trial count for any per-process probability away from one half (the tool's
header records the measured case that rules out a unanimity rule); the
canonical report is then stable by construction. The FNEW census has no
such channel — it never runs
the code — so `./bench/ci` still generates it twice and compares byte for
byte.
