local M = {}
local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
M.Golden_DirectiveArity_Test_Op = function(value0) return { value0 } end
M.Golden_DirectiveArity_Test_runOp = function(op)
  return function(x) return op[1](x) end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(42))()
  return Effect_Console_log(Data_Show_showIntImpl(42))()
end)()
