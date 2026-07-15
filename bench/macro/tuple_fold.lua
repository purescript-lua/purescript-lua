-- A fold-shaped loop carrying a Tuple accumulator. Call-pattern
-- specialization (issue #208) passes the two fields as raw loop
-- parameters, so the compiled loop does the same two-variable
-- accumulation as the ideal below and allocates the box only on the
-- exit path -- one table per call instead of one per iteration.
return {
  artifact = "Bench.TupleFold",
  n = 5e6,
  -- Ten calls of n/10 rather than one call of n: the same total work
  -- for the timing runners, but keeps each hot-counter's bumps within
  -- one recording attempt. See the note in array_foldl.lua.
  drive = function(mod, n)
    local acc
    for _ = 1, 10 do
      acc = mod.run(n / 10)
    end
    return acc
  end,
  ideal = function(n)
    local s, i = 0, 0
    while i < n do
      s, i = s + i, i + 1
    end
    return s
  end,
}
