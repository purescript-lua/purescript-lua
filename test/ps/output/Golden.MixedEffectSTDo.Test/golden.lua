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
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_MixedEffectSTDo_Test_tally = function(start)
  return Control_Monad_ST_Internal_foreign.run(function()
    local ref = Control_Monad_ST_Internal_foreign.new(start)()
    local _ = Control_Monad_ST_Internal_foreign.modifyImpl(function(s_S_0)
      local sPrime_S_0 = s_S_0 * 2
      return { state = sPrime_S_0, value = sPrime_S_0 }
    end)(ref)()
    local n = Control_Monad_ST_Internal_foreign.read(ref)()
    return n + 3
  end)
end
return (function()
  local _ = Effect_Console_log("mixing Effect and ST")()
  local x_S_0 = Golden_MixedEffectSTDo_Test_tally(2)
  local _ = Effect_Console_log(Data_Show_foreign.showIntImpl(x_S_0))()
  return Effect_Console_log("done")()
end)()
