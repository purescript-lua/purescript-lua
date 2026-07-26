-- Record surgery on a manifest literal per element: each element builds a
-- two-field record literal and unsafeSet copies it into a three-field
-- record, which the fold step reads back field by field. The ideal
-- variant builds the three-field table inline, so the gap isolates what
-- the compiled surgery still pays per element on top of the raw build.
return {
  artifact = "Bench.RecordSet",
  n = 1e6,
  -- Ten calls of n/10 rather than one call of n: the same total work for
  -- the timing runners, but keeps each hot-counter's bumps within one
  -- recording attempt. See the note in array_foldl.lua.
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
      local r = { a = i, b = i + 1, c = i + 2 }
      acc = acc + r.a + r.b + r.c
    end
    return acc
  end,
}
