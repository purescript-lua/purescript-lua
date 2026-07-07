-- A three-step Maybe bind chain per iteration: each step goes through the
-- Bind dictionary and allocates a Just constructor. The driver loop is the
-- hot loop here, so this also exercises what happens to a caller loop whose
-- callee cannot be traced.
return {
  artifact = "Bench.BindChain",
  n = 1e6,
  drive = function(mod, n)
    local acc = 0
    for _ = 1, n do
      acc = mod.run(acc)
    end
    return acc
  end,
  ideal = function(n)
    local acc = 0
    for _ = 1, n do
      acc = acc + 3
    end
    return acc
  end,
}
