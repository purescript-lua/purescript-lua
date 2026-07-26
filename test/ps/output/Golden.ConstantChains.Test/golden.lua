local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_ConstantChains_Test_foreign = {
  anInt = 100,
  anotherInt = 7,
  aString = "hello"
}
local Golden_ConstantChains_Test_aString = Golden_ConstantChains_Test_foreign.aString
local Golden_ConstantChains_Test_anInt = Golden_ConstantChains_Test_foreign.anInt
local Golden_ConstantChains_Test_anotherInt = Golden_ConstantChains_Test_foreign.anotherInt
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(1 + Golden_ConstantChains_Test_anInt + 2 + Golden_ConstantChains_Test_anotherInt + 3))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(2 * Golden_ConstantChains_Test_anInt * 30))()
  return Effect_Console_log((Golden_ConstantChains_Test_aString .. ", ") .. "world")()
end)()
