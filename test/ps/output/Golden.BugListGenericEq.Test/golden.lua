local M = {}
local Record_Unsafe_foreign = {
  unsafeGet = function(l) return function(r) return r[l] end end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Type_Proxy_Proxy = {}
local Data_HeytingAlgebra_heytingAlgebraBoolean
Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      return Data_HeytingAlgebra_heytingAlgebraBoolean.disj(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(a))(b)
    end
  end,
  conj = function(b1_S_232)
    return function(b2_S_233) return b1_S_232 and b2_S_233 end
  end,
  disj = function(b1_S_230)
    return function(b2_S_231) return b1_S_230 or b2_S_231 end
  end,
  _not_ = function(b_S_229) return not(b_S_229) end
}
local Data_Eq_eqRowCons_S_w = function( dictEqRecord
, eqRowCons_S_u2
, dictIsSymbol
, dictEq )
  return {
    eqRecord = function()
      return function(ra)
        return function(rb)
          local key = dictIsSymbol.reflectSymbol(Type_Proxy_Proxy)
          local get = Record_Unsafe_foreign.unsafeGet(key)
          return Data_HeytingAlgebra_heytingAlgebraBoolean.conj(dictEq.eq(get(ra))(get(rb)))(dictEqRecord.eqRecord(Type_Proxy_Proxy)(ra)(rb))
        end
      end
    end
  }
end
local Golden_BugListGenericEq_Test_Nil = {
  ["$ctor"] = "Golden.BugListGenericEq.Test∷List.Nil"
}
local Golden_BugListGenericEq_Test_Cons = function(value0)
  return {
    ["$ctor"] = "Golden.BugListGenericEq.Test∷List.Cons",
    value0 = value0
  }
end
M.Golden_BugListGenericEq_Test_genericList = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x["$ctor"] then
      return Golden_BugListGenericEq_Test_Nil
    elseif "Data.Generic.Rep∷Sum.Inr" == x["$ctor"] then
      return Golden_BugListGenericEq_Test_Cons(x.value0)
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    if "Golden.BugListGenericEq.Test∷List.Nil" == x0["$ctor"] then
      return (function(value0)
        return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inl", value0 = value0 }
      end)({})
    elseif "Golden.BugListGenericEq.Test∷List.Cons" == x0["$ctor"] then
      return (function(value0)
        return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inr", value0 = value0 }
      end)(x0.value0)
    else
      return error("No patterns matched")
    end
  end
}
local Golden_BugListGenericEq_Test_eqList
Golden_BugListGenericEq_Test_eqList = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return (function()
          local v_S_13 = (function()
            if "Golden.BugListGenericEq.Test∷List.Nil" == x["$ctor"] then
              return (function(value0)
                return {
                  ["$ctor"] = "Data.Generic.Rep∷Sum.Inl",
                  value0 = value0
                }
              end)({})
            elseif "Golden.BugListGenericEq.Test∷List.Cons" == x["$ctor"] then
              return (function(value0)
                return {
                  ["$ctor"] = "Data.Generic.Rep∷Sum.Inr",
                  value0 = value0
                }
              end)(x.value0)
            else
              return error("No patterns matched")
            end
          end)()
          return function(v1_S_14)
            if "Data.Generic.Rep∷Sum.Inl" == v_S_13["$ctor"] then
              return "Data.Generic.Rep∷Sum.Inl" == v1_S_14["$ctor"]
            elseif "Data.Generic.Rep∷Sum.Inr" == v_S_13["$ctor"] then
              if "Data.Generic.Rep∷Sum.Inr" == v1_S_14["$ctor"] then
                return (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
                  eqRecord = function()
                    return function() return function() return true end end
                  end
                }, nil, {
                  reflectSymbol = function() return "tail" end
                }, Golden_BugListGenericEq_Test_eqList(dictEq)), nil, {
                  reflectSymbol = function() return "head" end
                }, dictEq)).eqRecord(Type_Proxy_Proxy)(v_S_13.value0)(v1_S_14.value0)
              else
                return false
              end
            else
              return false
            end
          end
        end)()((function()
          if "Golden.BugListGenericEq.Test∷List.Nil" == y["$ctor"] then
            return (function(value0)
              return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inl", value0 = value0 }
            end)({})
          elseif "Golden.BugListGenericEq.Test∷List.Cons" == y["$ctor"] then
            return (function(value0)
              return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inr", value0 = value0 }
            end)(y.value0)
          else
            return error("No patterns matched")
          end
        end)())
      end
    end
  }
end
local Golden_BugListGenericEq_Test_eq = (Golden_BugListGenericEq_Test_eqList({
  eq = function(r1_S_225_S_238)
    return function(r2_S_226_S_239) return r1_S_225_S_238 == r2_S_226_S_239 end
  end
})).eq
local Golden_BugListGenericEq_Test_cons_S_w = function(head, tail)
  return Golden_BugListGenericEq_Test_Cons({ head = head, tail = tail })
end
return (function()
  local _ = (function()
    local a_S_2_S_270 = Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_Nil)(Golden_BugListGenericEq_Test_Nil)
    return Effect_Console_log((function()
      if a_S_2_S_270 then
        return "true"
      elseif false == a_S_2_S_270 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_271 = Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil)))(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil)))
    return Effect_Console_log((function()
      if a_S_2_S_271 then
        return "true"
      elseif false == a_S_2_S_271 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_2_S_272 = Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_Nil))(Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil))
    return Effect_Console_log((function()
      if a_S_2_S_272 then
        return "true"
      elseif false == a_S_2_S_272 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
