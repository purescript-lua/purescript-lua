local M = {}
local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_FloatIn_Test_foreign = {
  tick = function(n) print("tick") return n + n end
}
local Golden_FloatIn_Test_tick = Golden_FloatIn_Test_foreign.tick
M.Golden_FloatIn_Test_expensive = function(x) return x * x + 1 end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(20))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(0))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local shared_S_0 = Golden_FloatIn_Test_tick(3)
    local f_S_0 = function() return shared_S_0 + shared_S_0 end
    return f_S_0(Data_Unit_unit) + f_S_0(Data_Unit_unit)
  end)()))()
  return Effect_Console_log(Data_Show_showIntImpl(0))()
end)()
