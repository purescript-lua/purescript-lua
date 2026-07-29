### Fixed

- The bench counter oracle no longer reddens CI on trace-formation noise
  (#346). `./bench/ci` diffs committed reports of what LuaJIT did to each
  linked benchmark artifact; two of the three are static walks and byte-stable,
  but the per-spec trace report records which source locations ended up
  carrying a compiled trace (`J*` opcodes) or a blacklist (`I*`), and whether a
  given location does is a per-process dice roll — LuaJIT's hot counters live
  in a small hashed table keyed by bytecode address, so dropping one hoisted
  table from an artifact reshuffles which counters collide. `trace_report.lua`
  votes over nine fresh processes, which pins any spot forming with per-process
  probability near 0 or 1 and leaves one near ½ a coin flip.

  Measured over 30 raw single-process trials per spec, that is a class rather
  than a case: 14 entries across 8 of the 12 specs land strictly between
  "never" and "always", in both measured signals, the widest being

  ```
  spec         raw/30  golden   entry
  ref_loop     21/30   present  Bench.RefLoop.lua:32 JFUNCF
  ref_loop      8/30   absent   Bench.RefLoop.lua:35 -- inner loop in root trace
  record_set    4/30   absent   Bench.RecordSet.lua:6 -- inner loop in root trace
  ctor_build   26/30   present  Bench.CtorBuild.lua:3 JFUNCF
  array_foldl  27/30   present  Bench.ArrayFoldl.lua:20 -- NYI: bytecode FNEW
  ```

  The comparison now lives in `bench/tools/diff_counters`, which re-measures a
  trace report that differs from its golden **only** in those two sets and
  fails only if every attempt still differs (two re-measurements by default,
  `BENCH_TRACE_RETRIES` overrides, `0` restores a plain diff). A census
  difference, a report header difference, or a report existing on one side only
  is deterministic by construction and fails at once, buying no fresh
  processes. Replaying the comparison for `ref_loop` against its committed
  golden 300 times, paired on the same measurements:

  ```
  retries=0 over 300 runs: red=9, absorbed-by-re-measurement=0
  retries=2 over 300 runs: red=0, absorbed-by-re-measurement=10
  ```

  Re-measuring is conjunctive, which is what makes it a better use of fresh
  processes than a longer vote: for one entry at probability `p`, a nine-trial
  vote misreports with `P(Binom(9,p) ≤ 4)` and each re-measurement multiplies
  that in — 26.7% → 7.1% → 1.9% at `p = 0.6`, where pooling 25 trials into a
  single vote reaches only 15.4%. A reproducible change re-measures to the same
  thing every time and still fails; what is given up is a regression landing
  near `p = 0.5`, which has no pinnable golden on either side even with one
  vote. `bench/tools/counters_selftest` pins those verdicts against synthetic
  reports and runs in CI ahead of the counters.
