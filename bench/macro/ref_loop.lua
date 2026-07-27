-- A hot ST loop accumulating through a non-escaping local STRef. Unboxed
-- (issue #239) the loop body is plain arithmetic on a Lua local; boxed,
-- every iteration allocates the modify record and indexes the cell table.
return {
  artifact = "Bench.RefLoop",
  n = 100000,
  drive = function(mod, n)
    return mod.run(n)
  end,
  ideal = function(n)
    local acc = 0
    for i = 0, n - 1 do acc = acc + i end
    return acc
  end,
}
