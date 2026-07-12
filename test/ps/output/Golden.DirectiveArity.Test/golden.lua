local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_DirectiveArity_Test_Op = function(value0)
  return { value0 = value0 }
end
M.Golden_DirectiveArity_Test_runOp = function(op)
  return function(x) return op.value0(x) end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(42))()
  return Effect_Console_log(Data_Show_showIntImpl(42))()
end)()
