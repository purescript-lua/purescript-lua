### Added

- A `bench/` harness measuring generated code. `./bench/run` times
  hand-written micro patterns (curried application, dictionary-driven
  comparison, constructor allocation + tag match, module-field access) and
  linked `Bench.*` macro modules (fib recursion, `foldl` over an array with
  a curried step, a Maybe bind chain) under PUC Lua and LuaJIT, with and
  without the JIT. `./bench/ci` regenerates deterministic LuaJIT counters
  and diffs them against committed oracles in `bench/goldens/`: a static
  FNEW census per linked artifact (split into main-chunk occurrences, which
  run once at load, and function-body occurrences, which allocate per call
  and abort trace recording) and a trace report of distinct abort sites
  plus the end state of loop/function bytecodes (`J*` compiled, `I*`
  blacklisted). CI runs `./bench/ci` after the test suite; the dev shell
  gains `luajit` (#172).
