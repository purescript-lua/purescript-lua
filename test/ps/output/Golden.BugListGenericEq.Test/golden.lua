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
  conj = function(b1_S_229)
    return function(b2_S_230) return b1_S_229 and b2_S_230 end
  end,
  disj = function(b1_S_227)
    return function(b2_S_228) return b1_S_227 or b2_S_228 end
  end,
  _not_ = function(b_S_226) return not(b_S_226) end
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
  "Golden.BugListGenericEq.Test∷List.Nil"
}
local Golden_BugListGenericEq_Test_Cons = function(value0)
  return { "Golden.BugListGenericEq.Test∷List.Cons", value0 }
end
M.Golden_BugListGenericEq_Test_genericList = {
  to = function(x)
    local _S_cse264 = x[1]
    if "Data.Generic.Rep∷Sum.Inl" == _S_cse264 then
      return Golden_BugListGenericEq_Test_Nil
    elseif "Data.Generic.Rep∷Sum.Inr" == _S_cse264 then
      return Golden_BugListGenericEq_Test_Cons(x[2])
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    local _S_cse265 = x0[1]
    if "Golden.BugListGenericEq.Test∷List.Nil" == _S_cse265 then
      return (function(value0)
        return { "Data.Generic.Rep∷Sum.Inl", value0 }
      end)({})
    elseif "Golden.BugListGenericEq.Test∷List.Cons" == _S_cse265 then
      return (function(value0)
        return { "Data.Generic.Rep∷Sum.Inr", value0 }
      end)(x0[2])
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
        local _S_cse268 = y[1]
        local _S_cse267 = x[1]
        local _S_cse266 = (function(value0)
          return { "Data.Generic.Rep∷Sum.Inl", value0 }
        end)({})
        return (function()
          local v_S_13 = (function()
            if "Golden.BugListGenericEq.Test∷List.Nil" == _S_cse267 then
              return _S_cse266
            elseif "Golden.BugListGenericEq.Test∷List.Cons" == _S_cse267 then
              return (function(value0)
                return { "Data.Generic.Rep∷Sum.Inr", value0 }
              end)(x[2])
            else
              return error("No patterns matched")
            end
          end)()
          return function(v1_S_14)
            local _S_cse270 = v1_S_14[1]
            local _S_cse269 = v_S_13[1]
            if "Data.Generic.Rep∷Sum.Inl" == _S_cse269 then
              return "Data.Generic.Rep∷Sum.Inl" == _S_cse270
            elseif "Data.Generic.Rep∷Sum.Inr" == _S_cse269 then
              if "Data.Generic.Rep∷Sum.Inr" == _S_cse270 then
                return (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
                  eqRecord = function()
                    return function() return function() return true end end
                  end
                }, nil, {
                  reflectSymbol = function() return "tail" end
                }, Golden_BugListGenericEq_Test_eqList(dictEq)), nil, {
                  reflectSymbol = function() return "head" end
                }, dictEq)).eqRecord(Type_Proxy_Proxy)(v_S_13[2])(v1_S_14[2])
              else
                return false
              end
            else
              return false
            end
          end
        end)()((function()
          if "Golden.BugListGenericEq.Test∷List.Nil" == _S_cse268 then
            return _S_cse266
          elseif "Golden.BugListGenericEq.Test∷List.Cons" == _S_cse268 then
            return (function(value0)
              return { "Data.Generic.Rep∷Sum.Inr", value0 }
            end)(y[2])
          else
            return error("No patterns matched")
          end
        end)())
      end
    end
  }
end
local Golden_BugListGenericEq_Test_eq = (Golden_BugListGenericEq_Test_eqList({
  eq = function(r1_S_233)
    return function(r2_S_234) return r1_S_233 == r2_S_234 end
  end
})).eq
local Golden_BugListGenericEq_Test_cons_S_w = function(head, tail)
  return Golden_BugListGenericEq_Test_Cons({ head = head, tail = tail })
end
return (function()
  local _ = (function()
    local a_S_261 = Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_Nil)(Golden_BugListGenericEq_Test_Nil)
    return Effect_Console_log((function()
      if a_S_261 then
        return "true"
      elseif false == a_S_261 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_262 = Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil)))(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil)))
    return Effect_Console_log((function()
      if a_S_262 then
        return "true"
      elseif false == a_S_262 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_263 = Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_Nil))(Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil))
    return Effect_Console_log((function()
      if a_S_263 then
        return "true"
      elseif false == a_S_263 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
