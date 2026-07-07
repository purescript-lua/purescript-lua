-- A hot two-argument loop, always fully applied: uncurried into a direct
-- n-ary worker call, it is the canonical trace-compilable loop; curried,
-- every iteration allocates closures and the loop gets blacklisted.
return {
  artifact = "Bench.CurriedStep",
  n = 100000,
  drive = function(mod, n)
    return mod.run(n)
  end,
  ideal = function(n)
    local acc = 0
    for i = n, 1, -1 do acc = acc + i end
    return acc
  end,
}
