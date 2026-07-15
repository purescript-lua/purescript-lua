-- A State-shaped hot loop: each iteration threads the state through two
-- calls of a step returning a two-field Tuple, deconstructing each result
-- immediately. Today that is one table allocation per step; with the
-- result-side worker/wrapper split the step returns the pair as multiple
-- values and the loop allocates nothing.
return {
  artifact = "Bench.StateStep",
  n = 100000,
  drive = function(mod, n)
    return mod.run(n)
  end,
  ideal = function(n)
    local step = function(s)
      local a1 = s + 1
      local a2 = a1 + 3
      local a3 = a2 - s
      local a4 = a3 + a1
      local a5 = a4 + 2
      local a6 = a5 + a2
      local a7 = a6 - a3
      local a8 = a7 + a4
      local a9 = a8 + 1
      local a10 = a9 - a5
      local a11 = a10 + a6
      local a12 = a11 - a7
      local a13 = a12 + a8
      local a14 = a13 + a9
      local a15 = a14 - a10
      local a16 = a15 + a11
      return (a1 + a3 + a5 + a7 + a9 + a11 + a13 + a15) % 3,
        (a2 + a4 + a6 + a8 + a10 + a12 + a14 + a16) % 7
    end
    local acc, s = 0, 0
    for _ = n, 1, -2 do
      local a, s2 = step(s)
      local b, s3 = step(s2)
      acc, s = acc + a + b, s3
    end
    return acc
  end,
}
