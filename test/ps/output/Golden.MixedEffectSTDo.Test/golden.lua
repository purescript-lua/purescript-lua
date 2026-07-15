local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Control_Monad_ST_Internal_foreign = {
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end,
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
local Control_Monad_ST_Internal_modifyImpl = Control_Monad_ST_Internal_foreign.modifyImpl
local Control_Monad_ST_Internal_new = Control_Monad_ST_Internal_foreign.new
local Control_Monad_ST_Internal_read = Control_Monad_ST_Internal_foreign.read
local Control_Monad_ST_Internal_run = Control_Monad_ST_Internal_foreign.run
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_MixedEffectSTDo_Test_tally = function(start)
  return Control_Monad_ST_Internal_run(function()
    local ref = Control_Monad_ST_Internal_new(start)()
    local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_8)
      local sPrime_S_9 = s_S_8 * 2
      return { state = sPrime_S_9, value = sPrime_S_9 }
    end)(ref)()
    local n = Control_Monad_ST_Internal_read(ref)()
    return n + 3
  end)
end
return (function()
  local _ = Effect_Console_log("mixing Effect and ST")()
  local x_S_0 = Control_Monad_ST_Internal_run(function()
    local ref_S_458 = Control_Monad_ST_Internal_new(2)()
    local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_460)
      local sPrime_S_461 = s_S_460 * 2
      return { state = sPrime_S_461, value = sPrime_S_461 }
    end)(ref_S_458)()
    local n_S_459 = Control_Monad_ST_Internal_read(ref_S_458)()
    return n_S_459 + 3
  end)
  local _ = Effect_Console_log(Data_Show_foreign.showIntImpl(x_S_0))()
  return Effect_Console_log("done")()
end)()
