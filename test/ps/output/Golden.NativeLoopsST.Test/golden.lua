local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Control_Monad_ST_Internal_foreign = {
  map_ = function(f)
    return function(a) return function() return f(a()) end end
  end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end,
  _while_ = function(f)
    return function(a) return function() while f() do a() end end end
  end,
  _for_ = function(lo)
    return function(hi)
      return function(f)
        return function() for i = lo, hi - 1 do f(i)() end end
      end
    end
  end,
  foreach = function(as)
    return function(f)
      return function() for i = 1, #(as) do f(as[i])() end end
    end
  end,
  new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  modifyImpl = function(f)
    return function(ref)
      return function()
        local t = f(ref.value)
        ref.value = t.state
        return t.value
      end
    end
  end
}
local Control_Monad_ST_Internal_map_ = Control_Monad_ST_Internal_foreign.map_
local Control_Monad_ST_Internal_modifyImpl = Control_Monad_ST_Internal_foreign.modifyImpl
local Control_Monad_ST_Internal_new = Control_Monad_ST_Internal_foreign.new
local Control_Monad_ST_Internal_read = Control_Monad_ST_Internal_foreign.read
local Control_Monad_ST_Internal_run = Control_Monad_ST_Internal_foreign.run
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_NativeLoopsST_Test_logShow = function(a_S_2)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_2))
end
local Golden_NativeLoopsST_Test_sumTo = function(n)
  return Control_Monad_ST_Internal_run(function()
    local acc = Control_Monad_ST_Internal_new(0)()
    for i = 0, n + 1 - 1 do
      Control_Monad_ST_Internal_modifyImpl(function(s_S_490)
        local sPrime_S_491 = s_S_490 + i
        return { state = sPrime_S_491, value = sPrime_S_491 }
      end)(acc)()
    end
    return Control_Monad_ST_Internal_read(acc)()
  end)
end
local Golden_NativeLoopsST_Test_sumArray = function(xs)
  return Control_Monad_ST_Internal_run(function()
    local acc = Control_Monad_ST_Internal_new(0)()
    for _S_i0 = 1, #(xs) do
      local x = xs[_S_i0]
      Control_Monad_ST_Internal_map_(function()
        return Data_Unit_unit
      end)(Control_Monad_ST_Internal_modifyImpl(function(s_S_483)
        local sPrime_S_484 = s_S_483 + x
        return { state = sPrime_S_484, value = sPrime_S_484 }
      end)(acc))()
    end
    return Control_Monad_ST_Internal_read(acc)()
  end)
end
local Golden_NativeLoopsST_Test_countDown = function(start)
  return Control_Monad_ST_Internal_run(function()
    local steps = Control_Monad_ST_Internal_new(0)()
    local value = Control_Monad_ST_Internal_new(start)()
    do
      local _S_cond1 = Control_Monad_ST_Internal_map_(function(v)
        return not(v < 0) and v ~= 0
      end)(Control_Monad_ST_Internal_read(value))
      while _S_cond1() do
        local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_472)
          local sPrime_S_473 = s_S_472 - 1
          return { state = sPrime_S_473, value = sPrime_S_473 }
        end)(value)()
        Control_Monad_ST_Internal_modifyImpl(function(s_S_477)
          local sPrime_S_478 = s_S_477 + 1
          return { state = sPrime_S_478, value = sPrime_S_478 }
        end)(steps)()
      end
    end
    return Control_Monad_ST_Internal_read(steps)()
  end)
end
return (function()
  local _ = Golden_NativeLoopsST_Test_logShow(Golden_NativeLoopsST_Test_sumTo(10))()
  local _ = Golden_NativeLoopsST_Test_logShow(Golden_NativeLoopsST_Test_sumArray({
    [1] = 1,
    [2] = 2,
    [3] = 3,
    [4] = 4
  }))()
  return Golden_NativeLoopsST_Test_logShow(Golden_NativeLoopsST_Test_countDown(5))()
end)()
