-- A fold whose step builds a record, updates it, and reads the result
-- back field-wise -- never passing either table on whole. Unpacked
-- (issue #240) the step is plain arithmetic; boxed, every element
-- allocates the literal plus the update's runtime copy.
return {
  artifact = "Bench.RecordFold",
  n = 100000,
  drive = function(mod, n)
    return mod.run(n)
  end,
  ideal = function(n)
    local acc = 0
    for i = 1, n do acc = acc + i + (i + 1) * 2 end
    return acc
  end,
}
