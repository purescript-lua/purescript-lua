local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  write = function(val)
    return function(ref) return function() ref.value = val end end
  end
}
local Effect_Ref_read = Effect_Ref_foreign.read
local Control_Monad_ST_Internal_foreign = {
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end,
  _for_ = function(lo)
    return function(hi)
      return function(f)
        return function() for i = lo, hi - 1 do f(i)() end end
      end
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
  end,
  write = function(a)
    return function(ref) return function() ref.value = a return a end end
  end
}
local Control_Monad_ST_Internal_modifyImpl = Control_Monad_ST_Internal_foreign.modifyImpl
local Control_Monad_ST_Internal_new = Control_Monad_ST_Internal_foreign.new
local Control_Monad_ST_Internal_read = Control_Monad_ST_Internal_foreign.read
local Control_Monad_ST_Internal_run = Control_Monad_ST_Internal_foreign.run
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Semiring_semiringInt = {
  add = function(x_S_0) return function(y_S_0) return x_S_0 + y_S_0 end end,
  zero = 0,
  mul = function(x_S_1) return function(y_S_1) return x_S_1 * y_S_1 end end,
  one = 1
}
local Golden_RefUnbox_Test_logShow = function(a_S_0)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_0))
end
local Golden_RefUnbox_Test_writeBack = Control_Monad_ST_Internal_run(function()
  local r = Control_Monad_ST_Internal_new(1)()
  local x = Control_Monad_ST_Internal_foreign.write(7)(r)()
  local y = Control_Monad_ST_Internal_read(r)()
  return x + y
end)
local Golden_RefUnbox_Test_sumTo = function(n)
  return Control_Monad_ST_Internal_run(function()
    local acc = Control_Monad_ST_Internal_new(0)()
    for i = 0, n + 1 - 1 do
      Control_Monad_ST_Internal_modifyImpl(function(s_S_0)
        local sPrime_S_0 = s_S_0 + i
        return { state = sPrime_S_0, value = sPrime_S_0 }
      end)(acc)()
    end
    return Control_Monad_ST_Internal_read(acc)()
  end)
end
local Golden_RefUnbox_Test_splitModify = function(n)
  return Control_Monad_ST_Internal_run(function()
    local r = Control_Monad_ST_Internal_new(n)()
    local v = Control_Monad_ST_Internal_modifyImpl(function(s)
      return { state = s * 2, value = s + 100 }
    end)(r)()
    local s0 = Control_Monad_ST_Internal_read(r)()
    return v + s0
  end)
end
local Golden_RefUnbox_Test_nested = Control_Monad_ST_Internal_run(function()
  local inner = Control_Monad_ST_Internal_new(21)()
  local outer = Control_Monad_ST_Internal_new(inner)()
  local cell = Control_Monad_ST_Internal_read(outer)()
  local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_1)
    local sPrime_S_1 = s_S_1 * 2
    return { state = sPrime_S_1, value = sPrime_S_1 }
  end)(cell)()
  return Control_Monad_ST_Internal_read(cell)()
end)
return (function()
  local _ = Golden_RefUnbox_Test_logShow(Golden_RefUnbox_Test_sumTo(10))()
  local _ = Golden_RefUnbox_Test_logShow(Golden_RefUnbox_Test_splitModify(3))()
  local _ = Golden_RefUnbox_Test_logShow(Golden_RefUnbox_Test_writeBack)()
  local _ = Golden_RefUnbox_Test_logShow(Golden_RefUnbox_Test_nested)()
  local counter_S_0 = Effect_Ref_foreign._new(10)()
  local v_S_0 = Effect_Ref_read(counter_S_0)()
  local _ = Effect_Ref_foreign.write(Data_Semiring_semiringInt.add(v_S_0)(1))(counter_S_0)()
  local w_S_0 = Effect_Ref_read(counter_S_0)()
  return Golden_RefUnbox_Test_logShow(w_S_0)()
end)()
