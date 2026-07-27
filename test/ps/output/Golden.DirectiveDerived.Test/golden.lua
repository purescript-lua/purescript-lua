local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_DirectiveDerived_Test_combine = function(a)
  return function(b)
    return function(c)
      return c - a - 1 - b - 2 - a - 3 - b - 4 - a - 5 - b - 6 - a - 7 - b - 8 - a - 9 - b - 10 - a - 11 - b - 12 - a - 13 - b - 14 - a - 15 - b - 16 - a - 17 - b - 18 - a - 19 - b - 20
    end
  end
end
local Golden_DirectiveDerived_Test_oneOnly = Golden_DirectiveDerived_Test_combine(1)
local Golden_DirectiveDerived_Test_onePlusTwo = function(c_S_0)
  return c_S_0 - 1 - 1 - 2 - 2 - 1 - 3 - 2 - 4 - 1 - 5 - 2 - 6 - 1 - 7 - 2 - 8 - 1 - 9 - 2 - 10 - 1 - 11 - 2 - 12 - 1 - 13 - 2 - 14 - 1 - 15 - 2 - 16 - 1 - 17 - 2 - 18 - 1 - 19 - 2 - 20
end
local Golden_DirectiveDerived_Test_apply34 = function(f) return f(3)(4) end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DirectiveDerived_Test_onePlusTwo(100)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DirectiveDerived_Test_onePlusTwo(200)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DirectiveDerived_Test_oneOnly(50)(60)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DirectiveDerived_Test_apply34(Golden_DirectiveDerived_Test_oneOnly)))()
end)()
