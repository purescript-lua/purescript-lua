local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_Show_showInt = { show = Data_Show_showIntImpl }
local Data_Show_show = function(dict) return dict.show end
local Golden_EffectPureChain_Test_show = Data_Show_showIntImpl
local Golden_EffectPureChain_Test_count_S_w = function(n)
  local _ = Effect_Console_log("counting from " .. Golden_EffectPureChain_Test_show(n))()
  local x = n + 1
  local _ = Effect_Console_log("got " .. Golden_EffectPureChain_Test_show(x))()
  return x + x * 2
end
M.Golden_EffectPureChain_Test_count = function(count_S_p1)
  return function(count_S_p2)
    return Golden_EffectPureChain_Test_count_S_w(count_S_p1, count_S_p2)
  end
end
return (function()
  local total_S_0 = Golden_EffectPureChain_Test_count_S_w(20)
  return Effect_Console_log(Data_Show_show(Data_Show_showInt)(total_S_0))()
end)()
