local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_ForeignAccessorDefault_Test_foreign = {
  double = function(n) return n * 2 end,
  bump = function(n) return n + 1 end
}
local Golden_ForeignAccessorDefault_Test_double = Golden_ForeignAccessorDefault_Test_foreign.double
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ForeignAccessorDefault_Test_double(21)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ForeignAccessorDefault_Test_double(4)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_ForeignAccessorDefault_Test_foreign.bump(7)))()
end)()
