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
  timing runners work under both PUC Lua and LuaJIT. `diff_counters` is the
  oracle comparison (which mismatch is re-measured, which fails — see
  "Marginal trace spots"), and `counters_selftest` pins that verdict against
  synthetic reports.
- `goldens/` — committed counter reports; the CI oracle.

## Usage

```bash
./bench/run                 # all wall-clock benchmarks, all runtimes
lua bench/tools/run_micro.lua bench/micro/curried_apply.lua        # one bench
luajit bench/tools/run_macro.lua bench/macro/array_foldl.lua 5e6   # custom n
./bench/ci                  # regenerate counters, verify against goldens/
./bench/ci --accept         # rewrite goldens/ after a deliberate change
./bench/tools/counters_selftest   # pin the oracle's verdict logic (no LuaJIT run)
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
one run and not the next. `trace_report.lua` absorbs most of this by taking a
majority vote over several independent trials: a spot is reported iff most
processes form it, and the misreport odds decay binomially in the trial count
for any per-process probability away from one half (the tool's header records
the measured case that rules out a unanimity rule). A probability *near* one
half outlasts the vote, which is what the next section is about. The censuses
have no such channel — they never run the code — so `./bench/ci` still
generates each twice and compares byte for byte.

## Marginal trace spots

A spot's per-process formation probability `p` belongs to the whole process
layout, not to the bytecode alone: the hot counters are keyed by bytecode
address, so dropping one hoisted table from an artifact reshuffles which
counters collide and can move a spot off `p = 1` without changing what the
spot does. Any codegen change that shifts lines in a bench artifact can
therefore manufacture a marginal spot, and a marginal spot turns the vote
into a coin flip — reddening CI for a reason that has nothing to do with the
change under review.

That is a class, not a case. Measured over 30 raw single-process trials per
spec (`trace_report.lua <spec> --trial`), 14 entries across 8 of the 12 specs
land strictly between "never" and "always", the widest being:

```
spec         raw/30  golden   entry
ref_loop     21/30   present  Bench.RefLoop.lua:32 JFUNCF
ref_loop      8/30   absent   Bench.RefLoop.lua:35 -- inner loop in root trace
record_set    4/30   absent   Bench.RecordSet.lua:6 -- inner loop in root trace
ctor_build   26/30   present  Bench.CtorBuild.lua:3 JFUNCF
array_foldl  27/30   present  Bench.ArrayFoldl.lua:20 -- NYI: bytecode FNEW
```

Both measured signals are affected — opcode end states *and* abort sites — and
the two `ref_loop` entries are complementary, the abort being what gets
recorded when the entry trace does not form.

So `./bench/ci` treats the class uniformly instead of naming spots.
`diff_counters` compares each report to its golden and, when a *trace* report
differs **only** in the measured sets, re-measures it — a fresh canonical vote
— failing only if every attempt still differs. Two re-measurements is the
default; `BENCH_TRACE_RETRIES` overrides it, and `0` restores a plain diff.
A difference in a census, in a trace report's header lines, or in which
reports exist at all is deterministic by construction and fails immediately,
buying no fresh processes.

The re-measurements are conjunctive, which is why they beat spending the same
processes on one longer vote: for a single entry at probability `p`, one
nine-trial vote lands on the wrong side with `P(Binom(9,p) ≤ 4)`, and each
re-measurement multiplies that in — 26.7% → 7.1% → 1.9% at `p = 0.6`, where
pooling 25 trials into one vote only reaches 15.4%. What it gives up is a
regression that itself lands near `p = 0.5`; such a regression has no pinnable
golden on either side even with one vote, so nothing previously catchable
becomes uncatchable. A reproducible change re-measures to the same thing every
time and fails after spending the budget.

`counters_selftest` pins those verdicts against synthetic reports — a marginal
entry absorbed, a reproducible change failing after spending the budget, and a
census or header difference failing without buying any processes — so CI checks
the oracle's judgement before it trusts its counters.
