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
    if "Data.Ordering∷Ordering.GT" == (function()
      if n < 0 then
        return "Data.Ordering∷Ordering.LT"
      elseif n == 0 then
        return "Data.Ordering∷Ordering.EQ"
      else
        return "Data.Ordering∷Ordering.GT"
      end
    end)() then
      acc, n = acc + n, n - 1
    else
      return acc
    end
  end
end
M.Golden_Primops_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return Golden_Primops_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
return (function()
  local _ = Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showIntImpl
  }, Golden_Primops_Test_sumTo_S_w(0, 5))()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_241)
      if v_S_241 then
        return "true"
      elseif false == v_S_241 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, true)()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_245)
      if v_S_245 then
        return "true"
      elseif false == v_S_245 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, true)()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_113)
      if "Data.Ordering∷Ordering.LT" == v_S_113[1] then
        return "LT"
      elseif "Data.Ordering∷Ordering.GT" == v_S_113[1] then
        return "GT"
      elseif "Data.Ordering∷Ordering.EQ" == v_S_113[1] then
        return "EQ"
      else
        return error("No patterns matched")
      end
    end
  }, { "Data.Ordering∷Ordering.LT" })()
  local _ = Effect_Console_log("foobar")()
  return Effect_Console_logShow_S_w({
    show = function(v_S_251)
      if v_S_251 then
        return "true"
      elseif false == v_S_251 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, Data_HeytingAlgebra_heytingAlgebraBoolean.conj(true)(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(false)))()
end)()
