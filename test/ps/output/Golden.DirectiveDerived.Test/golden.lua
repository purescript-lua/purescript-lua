local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_DirectiveDerived_Test_combine = function(a)
  return function(b)
    return function(c)
      return c - a - 1 - b - 2 - a - 3 - b - 4 - a - 5 - b - 6 - a - 7 - b - 8 - a - 9 - b - 10 - a - 11 - b - 12 - a - 13 - b - 14 - a - 15 - b - 16 - a - 17 - b - 18 - a - 19 - b - 20
    end
  end
end
local Golden_DirectiveDerived_Test_oneOnly = Golden_DirectiveDerived_Test_combine(1)
local Golden_DirectiveDerived_Test_apply34 = function(f) return f(3)(4) end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(-140))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(-40))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(-660))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DirectiveDerived_Test_apply34(Golden_DirectiveDerived_Test_oneOnly)))()
end)()
