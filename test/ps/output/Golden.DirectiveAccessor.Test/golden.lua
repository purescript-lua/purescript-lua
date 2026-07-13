local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_DirectiveAccessor_Test_ops = {
  add = function(a) return function(b) return a + b end end,
  mul = function(a0) return function(b0) return a0 * b0 end end
}
local Golden_DirectiveAccessor_Test_mkOps = function(n)
  return {
    add = function(a)
      return function(b) return a + b + n + 10 + 20 + 30 + 40 + 50 + 60 end
    end,
    sub = function(a0)
      return function(b0) return a0 - b0 + n + 10 + 20 + 30 + 40 + 50 + 60 end
    end,
    mul = function(a1)
      return function(b1) return a1 * b1 + n + 10 + 20 + 30 + 40 + 50 + 60 end
    end,
    divide = function(a2)
      return function(b2) return a2 * 2 + b2 * 3 + n + 10 + 20 + 30 + 40 end
    end
  }
end
return (function()
  local _S_cse348 = Golden_DirectiveAccessor_Test_ops.mul
  local _ = Effect_Console_log(Data_Show_showIntImpl(_S_cse348(6)(7)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(_S_cse348(2)(3)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(252))()
  return Effect_Console_log(Data_Show_showIntImpl((Golden_DirectiveAccessor_Test_mkOps(2)).mul(3)(4)))()
end)()
