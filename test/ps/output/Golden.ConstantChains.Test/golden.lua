local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_ConstantChains_Test_foreign = {
  anInt = 100,
  anotherInt = 7,
  aString = "hello"
}
local Golden_ConstantChains_Test_aString = Golden_ConstantChains_Test_foreign.aString
local Golden_ConstantChains_Test_anInt = Golden_ConstantChains_Test_foreign.anInt
local Golden_ConstantChains_Test_anotherInt = Golden_ConstantChains_Test_foreign.anotherInt
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ConstantChains_Test_anInt + Golden_ConstantChains_Test_anotherInt + 6))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ConstantChains_Test_anInt * 60))()
  return Effect_Console_log(Golden_ConstantChains_Test_aString .. ", world")()
end)()
