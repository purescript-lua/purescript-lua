local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_HeytingAlgebra_heytingAlgebraBoolean
Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      return Data_HeytingAlgebra_heytingAlgebraBoolean.disj(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(a))(b)
    end
  end,
  conj = function(b1_S_0)
    return function(b2_S_0) return b1_S_0 and b2_S_0 end
  end,
  disj = function(b1_S_1)
    return function(b2_S_1) return b1_S_1 or b2_S_1 end
  end,
  _not_ = function(b_S_0) return not(b_S_0) end
}
local Golden_Primops_Test_sumTo_S_w = function(acc, n)
  while true do
    if n >= 0 and n ~= 0 then acc, n = acc + n, n - 1 else return acc end
  end
end
M.Golden_Primops_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return Golden_Primops_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
return (function()
  local _ = Effect_Console_log(Data_Show_foreign.showIntImpl(Golden_Primops_Test_sumTo_S_w(0, 5)))()
  local _ = Effect_Console_log("true")()
  local _ = Effect_Console_log("true")()
  local _ = Effect_Console_log("LT")()
  local _ = Effect_Console_log("foobar")()
  return Effect_Console_log((function()
    if Data_HeytingAlgebra_heytingAlgebraBoolean.conj(true)(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(false)) then
      return "true"
    else
      return "false"
    end
  end)())()
end)()
