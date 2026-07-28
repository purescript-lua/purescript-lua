local M = {}
local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
M.Golden_ArrayPatternMatch_Test_lastOfThree = function(v)
  if 3 == #(v) then return v[3] else return -1 end
end
M.Golden_ArrayPatternMatch_Test_firstTwo = function(v)
  if 2 == #(v) then return v[1] + v[2] else return -1 end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(30))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(-1))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(-1))()
  return Effect_Console_log(Data_Show_showIntImpl(9))()
end)()
