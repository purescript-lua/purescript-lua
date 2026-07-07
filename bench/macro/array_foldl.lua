-- Foldable `foldl` over an Array with a curried step: the FFI fold loop is
-- a plain Lua `for`, but compiling it means inlining the curried callee, so
-- the tracer aborts on FNEW and blacklists the loop. The ideal variant does
-- the same work — build the array, fold it — with an uncurried step.
return {
  artifact = "Bench.ArrayFoldl",
  n = 5e6,
  drive = function(mod, n)
    return mod.run(n)
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
