local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      else
        if state == 1 then
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
end
local M = {}
M.Data_HeytingAlgebra_foreign = {
  boolConj = function(b1) return function(b2) return b1 and b2 end end,
  boolDisj = function(b1) return function(b2) return b1 or b2 end end,
  boolNot = function(b) return not b end
}
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a) return function(f) return function() return f(a())() end end end
}
M.Type_Proxy_Proxy = {}
M.Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      return M.Data_HeytingAlgebra_heytingAlgebraBoolean.disj(M.Data_HeytingAlgebra_heytingAlgebraBoolean._not_(a))(b)
    end
  end,
  conj = M.Data_HeytingAlgebra_foreign.boolConj,
  disj = M.Data_HeytingAlgebra_foreign.boolDisj,
  _not_ = M.Data_HeytingAlgebra_foreign.boolNot
}
M.Data_Eq_eqRecord = function(dict) return dict.eqRecord end
M.Data_Eq_eq = function(dict) return dict.eq end
M.Data_Eq_eqRowCons = function(dictEqRecord)
  return function()
    return function(dictIsSymbol)
      return function(dictEq)
        return {
          eqRecord = function()
            return function(ra)
              return function(rb)
                local key = dictIsSymbol.reflectSymbol(M.Type_Proxy_Proxy)
                local get = (function(l) return function(r) return r[l] end end)(key)
                return M.Data_HeytingAlgebra_heytingAlgebraBoolean.conj(M.Data_Eq_eq(dictEq)(get(ra))(get(rb)))(M.Data_Eq_eqRecord(dictEqRecord)(M.Type_Proxy_Proxy)(ra)(rb))
              end
            end
          end
        }
      end
    end
  end
end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Eq_Generic_genericEqPrime = function(dict) return dict.genericEqPrime end
M.Data_Eq_Generic_genericEqConstructor = function(dictGenericEq)
  return {
    genericEqPrime = function(v)
      return function(v1)
        return M.Data_Eq_Generic_genericEqPrime(dictGenericEq)(v)(v1)
      end
    end
  }
end
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
    map = function(f_S_54)
      return function(a_S_55)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_54))(a_S_55)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_33 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_35)
        return function(a_S_36)
          return bind_S_33(f_S_35)(function(fPrime_S_37)
            return bind_S_33(a_S_36)(function(aPrime_S_38)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_37(aPrime_S_38))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_BugListGenericEq_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_BugListGenericEq_Test_logShow = function(a_S_2)
  return (function(s) return function() print(s) end end)((function()
    if a_S_2 then
      return "true"
    else
      if false == a_S_2 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  end)())
end
M.Golden_BugListGenericEq_Test_Nil = {
  ["$ctor"] = "Golden.BugListGenericEq.Test∷List.Nil"
}
M.Golden_BugListGenericEq_Test_Cons = function(value0)
  return {
    ["$ctor"] = "Golden.BugListGenericEq.Test∷List.Cons",
    value0 = value0
  }
end
M.Golden_BugListGenericEq_Test_genericList = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x["$ctor"] then
      return M.Golden_BugListGenericEq_Test_Nil
    else
      if "Data.Generic.Rep∷Sum.Inr" == x["$ctor"] then
        return M.Golden_BugListGenericEq_Test_Cons(x.value0)
      else
        return error("No patterns matched")
      end
    end
  end,
  from = function(x0)
    if "Golden.BugListGenericEq.Test∷List.Nil" == x0["$ctor"] then
      return (function(value0)
        return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inl", value0 = value0 }
      end)({})
    else
      if "Golden.BugListGenericEq.Test∷List.Cons" == x0["$ctor"] then
        return (function(value0)
          return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inr", value0 = value0 }
        end)(x0.value0)
      else
        return error("No patterns matched")
      end
    end
  end
}
M.Golden_BugListGenericEq_Test_eqList = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return (function()
          local from_S_4 = M.Golden_BugListGenericEq_Test_genericList.from
          return function(dictGenericEq_S_5)
            return function(x_S_7)
              return function(y_S_8)
                return M.Data_Eq_Generic_genericEqPrime(dictGenericEq_S_5)(from_S_4(x_S_7))(from_S_4(y_S_8))
              end
            end
          end
        end)()({
          genericEqPrime = function(v_S_13)
            return function(v1_S_14)
              if "Data.Generic.Rep∷Sum.Inl" == v_S_13["$ctor"] then
                if "Data.Generic.Rep∷Sum.Inl" == v1_S_14["$ctor"] then
                  return M.Data_Eq_Generic_genericEqPrime(M.Data_Eq_Generic_genericEqConstructor({
                    genericEqPrime = function()
                      return function() return true end
                    end
                  }))(v_S_13.value0)(v1_S_14.value0)
                else
                  return false
                end
              else
                if "Data.Generic.Rep∷Sum.Inr" == v_S_13["$ctor"] then
                  if "Data.Generic.Rep∷Sum.Inr" == v1_S_14["$ctor"] then
                    return M.Data_Eq_Generic_genericEqPrime(M.Data_Eq_Generic_genericEqConstructor({
                      genericEqPrime = function(v_S_21)
                        return function(v1_S_22)
                          return M.Data_Eq_eq({
                            eq = M.Data_Eq_eqRecord(M.Data_Eq_eqRowCons(M.Data_Eq_eqRowCons({
                              eqRecord = function()
                                return function()
                                  return function() return true end
                                end
                              end
                            })()({
                              reflectSymbol = function() return "tail" end
                            })(M.Golden_BugListGenericEq_Test_eqList(dictEq)))()({
                              reflectSymbol = function() return "head" end
                            })(dictEq))(M.Type_Proxy_Proxy)
                          })(v_S_21)(v1_S_22)
                        end
                      end
                    }))(v_S_13.value0)(v1_S_14.value0)
                  else
                    return false
                  end
                else
                  return false
                end
              end
            end
          end
        })(x)(y)
      end
    end
  }
end
M.Golden_BugListGenericEq_Test_eq = M.Data_Eq_eq(M.Golden_BugListGenericEq_Test_eqList({
  eq = (function()
    local refEq = function(r1) return function(r2) return r1 == r2 end end
    return refEq
  end)()
}))
M.Golden_BugListGenericEq_Test_cons = function(head)
  return function(tail)
    return M.Golden_BugListGenericEq_Test_Cons({ head = head, tail = tail })
  end
end
return (function()
  local _ = M.Golden_BugListGenericEq_Test_logShow(M.Golden_BugListGenericEq_Test_eq(M.Golden_BugListGenericEq_Test_Nil)(M.Golden_BugListGenericEq_Test_Nil))()
  local _ = M.Golden_BugListGenericEq_Test_logShow(M.Golden_BugListGenericEq_Test_eq(M.Golden_BugListGenericEq_Test_cons(1)(M.Golden_BugListGenericEq_Test_cons(2)(M.Golden_BugListGenericEq_Test_Nil)))(M.Golden_BugListGenericEq_Test_cons(1)(M.Golden_BugListGenericEq_Test_cons(2)(M.Golden_BugListGenericEq_Test_Nil))))()
  return M.Golden_BugListGenericEq_Test_logShow(M.Golden_BugListGenericEq_Test_eq(M.Golden_BugListGenericEq_Test_cons(1)(M.Golden_BugListGenericEq_Test_Nil))(M.Golden_BugListGenericEq_Test_cons(2)(M.Golden_BugListGenericEq_Test_Nil)))()
end)()
