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
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_STDoBlock_Test_sumTwice = function(n)
  return Control_Monad_ST_Internal_foreign.run(function()
    local _S_cse495 = function(s_S_455)
      local sPrime_S_456 = s_S_455 + n
      return { state = sPrime_S_456, value = sPrime_S_456 }
    end
    local ref = Control_Monad_ST_Internal_foreign.new(0)()
    local _ = Control_Monad_ST_Internal_modifyImpl(_S_cse495)(ref)()
    local _ = Control_Monad_ST_Internal_modifyImpl(_S_cse495)(ref)()
    local total = Control_Monad_ST_Internal_foreign.read(ref)()
    return total + 1
  end)
end
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_STDoBlock_Test_sumTwice(5)))()
