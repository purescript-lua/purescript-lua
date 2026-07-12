local M = {}
local Data_Unit_foreign = { unit = {} }
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_FloatIn_Test_foreign = {
  tick = function(n) print("tick") return n + n end
}
local Golden_FloatIn_Test_pickShared_S_w = function(useIt, n)
  if useIt then
    local shared = Golden_FloatIn_Test_foreign.tick(n)
    local f = function() return shared + shared end
    return f(Data_Unit_foreign.unit) + f(Data_Unit_foreign.unit)
  else
    return 0
  end
end
M.Golden_FloatIn_Test_expensive = function(x) return x * x + 1 end
local Golden_FloatIn_Test_pick_S_w = function(useIt, n)
  if useIt then
    local shared = n * n + 1
    return shared + shared
  else
    return 0
  end
end
return (function()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pick_S_w(true, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pick_S_w(false, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pickShared_S_w(true, 3)))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pickShared_S_w(false, 3)))()
end)()
