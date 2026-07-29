-- A hot ST loop whose per-iteration step is a two-argument effect action,
-- always fully applied and immediately run. Two real arguments saturate the
-- spine before magicDo runs, so the uncurry split fires at the real arity and
-- the thunk ends up inside the worker: every iteration allocates that closure
-- and pays a second call to force it. With the thunk parameter absorbed into
-- the worker the iteration is one n-ary call and no allocation.
-- `effect_step.lua` is the unary sibling, which the late uncurry run covers.
return {
  artifact = "Bench.EffectStep2",
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
