-- A hot ST loop whose per-iteration step is a unary effect action, always
-- fully applied and immediately run. Uncurried late (after magicDo), the
-- step is one n-ary worker call per iteration; curried, every iteration
-- allocates the thunk closure and pays a second call to force it.
return {
  artifact = "Bench.EffectStep",
  n = 100000,
  drive = function(mod, n)
    return mod.run(n)
  end,
  ideal = function(n)
    local acc = 0
    for _ = 1, n do acc = acc + 15 end
    return acc
  end,
}
