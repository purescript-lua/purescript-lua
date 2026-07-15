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
local Golden_STDoBlock_Test_add_S_w = function(x_S_447, y_S_448)
  return x_S_447 + y_S_448
end
M.Golden_STDoBlock_Test_sumTwice = function(n)
  return Control_Monad_ST_Internal_run(function()
    local _S_cse469 = function(s_S_453)
      local sPrime_S_454 = Golden_STDoBlock_Test_add_S_w(s_S_453, n)
      return { state = sPrime_S_454, value = sPrime_S_454 }
    end
    local ref = Control_Monad_ST_Internal_new(0)()
    local _ = Control_Monad_ST_Internal_modifyImpl(_S_cse469)(ref)()
    local _ = Control_Monad_ST_Internal_modifyImpl(_S_cse469)(ref)()
    local total = Control_Monad_ST_Internal_read(ref)()
    return Golden_STDoBlock_Test_add_S_w(total, 1)
  end)
end
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Control_Monad_ST_Internal_run(function(  )
  local _S_cse470 = function(s_S_464)
    local sPrime_S_465 = Golden_STDoBlock_Test_add_S_w(s_S_464, 5)
    return { state = sPrime_S_465, value = sPrime_S_465 }
  end
  local ref_S_459 = Control_Monad_ST_Internal_new(0)()
  local _ = Control_Monad_ST_Internal_modifyImpl(_S_cse470)(ref_S_459)()
  local _ = Control_Monad_ST_Internal_modifyImpl(_S_cse470)(ref_S_459)()
  local total_S_460 = Control_Monad_ST_Internal_read(ref_S_459)()
  return Golden_STDoBlock_Test_add_S_w(total_S_460, 1)
end)))()
