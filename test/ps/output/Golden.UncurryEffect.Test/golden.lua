local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_UncurryEffect_Test_tick = function(n)
  return function()
    local _ = Effect_Console_log("tick")()
    return Effect_Console_log(Data_Show_showIntImpl(n))()
  end
end
M.Golden_UncurryEffect_Test_runBoth = function(act)
  return function() local _ = act(1)() return act(2)() end
end
local Golden_UncurryEffect_Test_countdown
local Golden_UncurryEffect_Test_countdown_S_w = function(n)
  local _ = (function()
    local _ = Effect_Console_log("tick")()
    return Effect_Console_log(Data_Show_showIntImpl(n))()
  end)()
  return (function()
    if (function() if n < 1 then return false else return n ~= 1 end end)() then
      return Golden_UncurryEffect_Test_countdown(n - 1)
    else
      return Effect_Console_log("done")
    end
  end)()()
end
Golden_UncurryEffect_Test_countdown = function(countdown_S_p1)
  return function(countdown_S_p2)
    return Golden_UncurryEffect_Test_countdown_S_w(countdown_S_p1, countdown_S_p2)
  end
end
return (function()
  local _ = (function()
    local _ = Effect_Console_log("tick")()
    return Effect_Console_log(Data_Show_showIntImpl(7))()
  end)()
  local _ = Golden_UncurryEffect_Test_countdown_S_w(3)
  local _ = (function()
    local _ = (function()
      local _ = Effect_Console_log("tick")()
      return Effect_Console_log(Data_Show_showIntImpl(1))()
    end)()
    return (function()
      local _ = Effect_Console_log("tick")()
      return Effect_Console_log(Data_Show_showIntImpl(2))()
    end)()
  end)()
  return (function()
    local _ = Golden_UncurryEffect_Test_countdown_S_w(1)
    return Golden_UncurryEffect_Test_countdown_S_w(2)
  end)()
end)()
