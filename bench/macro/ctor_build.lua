-- Building a three-field data value per element and reading its fields back.
-- Each saturated constructor application is a curried closure chain, so
-- constructing one value allocates a closure per field past the first (an
-- FNEW under LuaJIT, aborting the trace) before the table is built. The
-- ideal variant does the same work by building the table directly.
return {
  artifact = "Bench.CtorBuild",
  n = 1e6,
  -- Ten calls of n/10 rather than one call of n: the same total work for the
  -- timing runners, but keeps each hot-counter's bumps within one recording
  -- attempt. See the note in array_foldl.lua.
  drive = function(mod, n)
    local acc
    for _ = 1, 10 do
      acc = mod.run(n / 10)
    end
    return acc
  end,
  ideal = function(n)
    local acc = 0
    for i = 1, n do
      local v = { "V", i, i + 1, i + 2 }
      acc = acc + v[2] + v[3] + v[4]
    end
    return acc
  end,
}
