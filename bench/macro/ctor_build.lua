-- Building a three-field data value per element and reading its fields back.
-- The ideal variant does the same work with the table built inline, so the
-- gap between the two isolates whatever the compiled constructor still pays
-- per element on top of the raw table build.
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
