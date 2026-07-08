local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      elseif state == 1 then
        return error(name .. " was needed before it finished initializing")
      else
        state = 1
        val = init()
        state = 2
        return val
      end
    end
  end
end
local M = {}
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Data_HeytingAlgebra__not_ = function(dict) return dict._not_ end
M.Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      local Data_HeytingAlgebra_heytingAlgebraBoolean = M.Data_HeytingAlgebra_heytingAlgebraBoolean
      return Data_HeytingAlgebra_heytingAlgebraBoolean.disj(M.Data_HeytingAlgebra__not_(Data_HeytingAlgebra_heytingAlgebraBoolean)(a))(b)
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
M.Data_Eq_eqInt = {
  eq = function(r1_S_206)
    return function(r2_S_207) return r1_S_206 == r2_S_207 end
  end
}
M.Data_Ord_ordInt = {
  compare = function(x_S_190)
    return function(y_S_191)
      if x_S_190 < y_S_191 then
        return { ["$ctor"] = "Data.Ordering∷Ordering.LT" }
      elseif x_S_190 == y_S_191 then
        return { ["$ctor"] = "Data.Ordering∷Ordering.EQ" }
      else
        return { ["$ctor"] = "Data.Ordering∷Ordering.GT" }
      end
    end
  end,
  Eq0 = function() return M.Data_Eq_eqInt end
}
M.Data_Ord_compare = function(dict) return dict.compare end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Effect_monadEffect = {
  Applicative0 = function() return M.Effect_applicativeEffect end,
  Bind1 = function() return M.Effect_bindEffect end
}
M.Effect_bindEffect = {
  bind = M.Effect_foreign.bindE,
  Apply0 = function() return M.Effect_Lazy_applyEffect(0) end
}
M.Effect_applicativeEffect = {
  pure = M.Effect_foreign.pureE,
  Apply0 = function() return M.Effect_Lazy_applyEffect(0) end
}
M.Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_25)
      return function(a_S_26)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_25))(a_S_26)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_4 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_6)
        return function(a_S_7)
          return bind_S_4(f_S_6)(function(fPrime_S_8)
            return bind_S_4(a_S_7)(function(aPrime_S_9)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_8(aPrime_S_9))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Effect_Console_logShow_S_w = function(dictShow, a)
  return M.Effect_Console_foreign.log(dictShow.show(a))
end
M.Golden_Primops_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_Primops_Test_logShow = function(logShow_S_p2_S_237)
  return M.Effect_Console_logShow_S_w({
    show = function(v_S_117)
      if v_S_117 then
        return "true"
      elseif false == v_S_117 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, logShow_S_p2_S_237)
end
M.Golden_Primops_Test_sumTo_S_w = function(acc, n)
  local Data_Ord_compare, Data_Ord_ordInt = M.Data_Ord_compare, M.Data_Ord_ordInt
  while true do
    if (function()
      if "Data.Ordering∷Ordering.GT" == (Data_Ord_compare(Data_Ord_ordInt)(n)(0))["$ctor"] then
        return false
      else
        return true
      end
    end)() then
      return acc
    else
      acc, n = acc + n, n - 1
    end
  end
end
M.Golden_Primops_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return M.Golden_Primops_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
return (function()
  local Golden_Primops_Test_logShow, Data_HeytingAlgebra_heytingAlgebraBoolean, Data_Ord_compare, Data_Ord_ordInt, Effect_Console_logShow_S_w = M.Golden_Primops_Test_logShow, M.Data_HeytingAlgebra_heytingAlgebraBoolean, M.Data_Ord_compare, M.Data_Ord_ordInt, M.Effect_Console_logShow_S_w
  local _ = Effect_Console_logShow_S_w({
    show = M.Data_Show_foreign.showIntImpl
  }, M.Golden_Primops_Test_sumTo_S_w(0, 5))()
  local _ = Golden_Primops_Test_logShow((function()
    if "Data.Ordering∷Ordering.LT" == (Data_Ord_compare(Data_Ord_ordInt)(7)(3))["$ctor"] then
      return false
    else
      return true
    end
  end)())()
  local _ = Golden_Primops_Test_logShow(M.Data_Eq_eqInt.eq(3)(3))()
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
  }, Data_Ord_compare(Data_Ord_ordInt)(2)(5))()
  local _ = M.Effect_Console_foreign.log("foobar")()
  return Golden_Primops_Test_logShow(Data_HeytingAlgebra_heytingAlgebraBoolean.conj(true)(M.Data_HeytingAlgebra__not_(Data_HeytingAlgebra_heytingAlgebraBoolean)(false)))()
end)()
