local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
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
