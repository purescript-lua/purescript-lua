local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_HeytingAlgebra_heytingAlgebraBoolean
Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      return Data_HeytingAlgebra_heytingAlgebraBoolean.disj(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(a))(b)
    end
  end,
  conj = function(b1_S_213)
    return function(b2_S_214) return b1_S_213 and b2_S_214 end
  end,
  disj = function(b1_S_211)
    return function(b2_S_212) return b1_S_211 or b2_S_212 end
  end,
  _not_ = function(b_S_210) return not(b_S_210) end
}
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
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
    show = function(v_S_117_S_250)
      if v_S_117_S_250 then
        return "true"
      elseif false == v_S_117_S_250 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, true)()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_117_S_254)
      if v_S_117_S_254 then
        return "true"
      elseif false == v_S_117_S_254 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, true)()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_116)
      if "Data.Ordering∷Ordering.LT" == v_S_116["$ctor"] then
        return "LT"
      elseif "Data.Ordering∷Ordering.GT" == v_S_116["$ctor"] then
        return "GT"
      elseif "Data.Ordering∷Ordering.EQ" == v_S_116["$ctor"] then
        return "EQ"
      else
        return error("No patterns matched")
      end
    end
  }, { ["$ctor"] = "Data.Ordering∷Ordering.LT" })()
  local _ = Effect_Console_foreign.log("foobar")()
  return Effect_Console_logShow_S_w({
    show = function(v_S_117_S_260)
      if v_S_117_S_260 then
        return "true"
      elseif false == v_S_117_S_260 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, Data_HeytingAlgebra_heytingAlgebraBoolean.conj(true)(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(false)))()
end)()
