-- The mutual twin of curried_step: the same hot accumulator loop, split
-- across two workers tail-calling each other. Dispatched, the pair runs
-- as one while-true loop over a branch selector; undispatched, every
-- iteration pays a real call for the transition.
return {
  artifact = "Bench.MutualStep",
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
