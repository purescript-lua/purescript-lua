local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_DirectiveArity_Test_Op = function(value0)
  return { value0 = value0 }
end
M.Golden_DirectiveArity_Test_runOp = function(op)
  return function(x) return op.value0(x) end
end
return (function()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(42))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(42))()
end)()
