local M = {}
M.Data_Unit_foreign = { unit = {} }
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_FloatIn_Test_foreign = {
  tick = function(n) print("tick") return n + n end
}
M.Golden_FloatIn_Test_pickShared_S_w = function(useIt, n)
  if useIt then
    local shared = M.Golden_FloatIn_Test_foreign.tick(n)
    local f = function() return shared + shared end
    return f(M.Data_Unit_foreign.unit) + f(M.Data_Unit_foreign.unit)
  else
    return 0
  end
end
M.Golden_FloatIn_Test_expensive = function(x) return x * x + 1 end
M.Golden_FloatIn_Test_pick_S_w = function(useIt, n)
  if useIt then
    local shared = n * n + 1
    return shared + shared
  else
    return 0
  end
end
return (function()
  local Data_Show_foreign, Effect_Console_foreign, Golden_FloatIn_Test_pickShared_S_w, Golden_FloatIn_Test_pick_S_w = M.Data_Show_foreign, M.Effect_Console_foreign, M.Golden_FloatIn_Test_pickShared_S_w, M.Golden_FloatIn_Test_pick_S_w
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pick_S_w(true, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pick_S_w(false, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pickShared_S_w(true, 3)))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_FloatIn_Test_pickShared_S_w(false, 3)))()
end)()
