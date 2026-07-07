### Added

- Self-recursive tail calls lower to `while true do` loops with parameter
  reassignment (#181): a recursive binding — an uncurried worker or a plain
  unary function, top-level or `let`-bound — whose tail position self-calls
  becomes a loop, with `return go$w(e₁, e₂)` turning into the simultaneous
  multiple assignment `p₁, p₂ = e₁, e₂`. Non-tail self-calls and other exits
  are untouched; a body that captures a parameter inside a nested closure
  (e.g. a CPS-style accumulator) is left recursive, since reassignment would
  corrupt the captured environment. PUC Lua already runs these shapes in
  constant stack via tail-call optimization, so the change is a constant
  factor there (no per-iteration CALL/RET and argument shuffling); under
  LuaJIT the loop is the shape the trace compiler wants, completing the
  uncurrying story of #24 for hot recursive workers like `span` and the fold
  fallbacks. The only observable difference is the shape of error tracebacks.
