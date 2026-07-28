local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_DistributeIntoIf_Test_flag = true
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
local Golden_DistributeIntoIf_Test__not_ = Data_HeytingAlgebra_heytingAlgebraBoolean._not_
local Golden_DistributeIntoIf_Test_weigh = function(x) return x * 3 end
local Golden_DistributeIntoIf_Test_pickName = function(b)
  if b then return "big" else return "small" end
end
local Golden_DistributeIntoIf_Test_chooseName = function(b)
  return function(l)
    return function(r) if b then return l.name else return r.name end end
  end
end
local Golden_DistributeIntoIf_Test_applyPicked = function(b)
  return function(n) if b then return n + 1 else return n * 2 end end
end
local Golden_DistributeIntoIf_Test_applyExpensive = function(b)
  return function(n)
    return (function()
      if b then
        return function(v) return v + 1 end
      else
        return function(v0) return v0 * 2 end
      end
    end)()(Golden_DistributeIntoIf_Test_weigh(n))
  end
end
return (function()
  local _ = Effect_Console_log(Golden_DistributeIntoIf_Test_pickName(Golden_DistributeIntoIf_Test_flag))()
  local _ = Effect_Console_log(Golden_DistributeIntoIf_Test_pickName(Golden_DistributeIntoIf_Test__not_(Golden_DistributeIntoIf_Test_flag)))()
  local _ = Effect_Console_log(Golden_DistributeIntoIf_Test_chooseName(Golden_DistributeIntoIf_Test_flag)({
    name = "left"
  })({ name = "right" }))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DistributeIntoIf_Test_applyPicked(Golden_DistributeIntoIf_Test_flag)(10)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DistributeIntoIf_Test_applyExpensive(Golden_DistributeIntoIf_Test__not_(Golden_DistributeIntoIf_Test_flag))(10)))()
end)()
