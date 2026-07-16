local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_EffectPureChain_Test_show = Data_Show_showIntImpl
M.Golden_EffectPureChain_Test_count = function(n)
  return function()
    local _ = Effect_Console_log("counting from " .. Golden_EffectPureChain_Test_show(n))()
    local x = n + 1
    local _ = Effect_Console_log("got " .. Golden_EffectPureChain_Test_show(x))()
    return x + x * 2
  end
end
return (function()
  local total_S_0 = (function()
    local _ = Effect_Console_log("counting from " .. Golden_EffectPureChain_Test_show(20))()
    local x_S_226 = 21
    local _ = Effect_Console_log("got " .. Golden_EffectPureChain_Test_show(x_S_226))()
    return 63
  end)()
  return Effect_Console_log(Data_Show_showIntImpl(total_S_0))()
end)()
