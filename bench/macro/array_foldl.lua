-- Foldable `foldl` over an Array with a curried step: the FFI fold loop is
-- a plain Lua `for`, but compiling it means inlining the curried callee, so
-- the tracer aborts on FNEW and blacklists the loop. The ideal variant does
-- the same work — build the array, fold it — with an uncurried step.
return {
  artifact = "Bench.ArrayFoldl",
  n = 5e6,
  -- Ten calls of n/10 rather than one call of n: the same total work for
  -- the timing runners, but the curried foldl entries inside `run` are
  -- bumped once per call, and a hot-counter that collects its bumps a
  -- whole workload apart can be decayed in between by a hash-colliding
  -- neighbour (see trace_report.lua). Ten keeps this driver loop's own
  -- bump count under the JIT's first retry penalty, so the loop gets
  -- exactly one recording attempt; at a hundred the retries introduce
  -- attempt races of their own.
  drive = function(mod, n)
    local acc
    for _ = 1, 10 do
      acc = mod.run(n / 10)
    end
    return acc
  end,
  ideal = function(n)
    local t = {}
    for i = 1, n do
      t[i] = i
    end
    local acc = 0
    for i = 1, #t do
      acc = acc + t[i]
    end
    return acc
  end,
}
