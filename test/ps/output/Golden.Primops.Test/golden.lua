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
  conj = function(b1_S_210)
    return function(b2_S_211) return b1_S_210 and b2_S_211 end
  end,
  disj = function(b1_S_208)
    return function(b2_S_209) return b1_S_208 or b2_S_209 end
  end,
  _not_ = function(b_S_207) return not(b_S_207) end
}
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_log(dictShow.show(a))
end
local Golden_Primops_Test_sumTo_S_w = function(acc, n)
  while true do
    if not(n < 0) and n ~= 0 then acc, n = acc + n, n - 1 else return acc end
  end
end
M.Golden_Primops_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return Golden_Primops_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
return (function()
  local _S_cse252 = {
    show = function(v_S_241)
      if v_S_241 then return "true" else return "false" end
    end
  }
  local _ = Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showIntImpl
  }, Golden_Primops_Test_sumTo_S_w(0, 5))()
  local _ = Effect_Console_logShow_S_w(_S_cse252, true)()
  local _ = Effect_Console_logShow_S_w(_S_cse252, true)()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_113)
      local _S_cse253 = v_S_113[1]
      if "Data.Ordering∷Ordering.LT" == _S_cse253 then
        return "LT"
      elseif "Data.Ordering∷Ordering.GT" == _S_cse253 then
        return "GT"
      elseif "Data.Ordering∷Ordering.EQ" == _S_cse253 then
        return "EQ"
      else
        return error("No patterns matched")
      end
    end
  }, { "Data.Ordering∷Ordering.LT" })()
  local _ = Effect_Console_log("foobar")()
  return Effect_Console_logShow_S_w(_S_cse252, Data_HeytingAlgebra_heytingAlgebraBoolean.conj(true)(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(false)))()
end)()
