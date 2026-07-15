### Added

- Call-pattern specialization for recursive bindings, GHC's SpecConstr
  discipline on the IR (#208): a recursive function that scrutinizes a
  parameter and passes a known constructor at that position in its recursive
  calls gets a specialized copy taking the constructor's fields as separate
  parameters, and every qualifying call site is rewritten to it. Fold-shaped
  loops with `Tuple`/`Maybe`/`Either` accumulators then carry raw values
  instead of allocating a box per iteration; the box materializes only where
  it escapes (the exit path). Specializations are capped per binding and
  minted one layer per specialize+dce round, so nested accumulators unbox
  incrementally without unbounded code growth. On the new `tuple_fold`
  macro benchmark the compiled loop drops the per-iteration table build,
  running ~2.5x faster under PUC Lua 5.1 (LuaJIT already sank the
  allocation inside its trace, so it is unchanged there).
