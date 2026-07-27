local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_UncurryEffect_Test_tick_S_w = function(n)
  local _ = Effect_Console_log("tick")()
  return Effect_Console_log(Data_Show_showIntImpl(n))()
end
local Golden_UncurryEffect_Test_tick = function(tick_S_p1)
  return function(tick_S_p2)
    return Golden_UncurryEffect_Test_tick_S_w(tick_S_p1, tick_S_p2)
  end
end
local Golden_UncurryEffect_Test_runBoth_S_w = function(act)
  local _ = act(1)()
  return act(2)()
end
M.Golden_UncurryEffect_Test_runBoth = function(runBoth_S_p1)
  return function(runBoth_S_p2)
    return Golden_UncurryEffect_Test_runBoth_S_w(runBoth_S_p1, runBoth_S_p2)
  end
end
local Golden_UncurryEffect_Test_countdown
local Golden_UncurryEffect_Test_countdown_S_w = function(n)
  local _ = (function()
    local _ = Effect_Console_log("tick")()
    return Effect_Console_log(Data_Show_showIntImpl(n))()
  end)()
  if n >= 1 and n ~= 1 then
    return Golden_UncurryEffect_Test_countdown(n - 1)()
  else
    return Effect_Console_log("done")()
  end
end
Golden_UncurryEffect_Test_countdown = function(countdown_S_p1)
  return function(countdown_S_p2)
    return Golden_UncurryEffect_Test_countdown_S_w(countdown_S_p1, countdown_S_p2)
  end
end
return (function()
  local _ = Golden_UncurryEffect_Test_tick_S_w(7)
  local _ = Golden_UncurryEffect_Test_countdown_S_w(3)
  local _ = Golden_UncurryEffect_Test_runBoth_S_w(Golden_UncurryEffect_Test_tick)
  return Golden_UncurryEffect_Test_runBoth_S_w(Golden_UncurryEffect_Test_countdown)
end)()
