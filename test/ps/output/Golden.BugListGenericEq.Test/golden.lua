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
  conj = function(b1_S_0)
    return function(b2_S_0) return b1_S_0 and b2_S_0 end
  end,
  disj = function(b1_S_1)
    return function(b2_S_1) return b1_S_1 or b2_S_1 end
  end,
  _not_ = function(b_S_0) return not(b_S_0) end
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
M.Golden_BugListGenericEq_Test_Cons = function(value0)
  return { "Golden.BugListGenericEq.Test∷List.Cons", value0 }
end
M.Golden_BugListGenericEq_Test_genericList = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x[1] then
      return Golden_BugListGenericEq_Test_Nil
    else
      return { "Golden.BugListGenericEq.Test∷List.Cons", x[2] }
    end
  end,
  from = function(x0)
    if "Golden.BugListGenericEq.Test∷List.Nil" == x0[1] then
      return { "Data.Generic.Rep∷Sum.Inl", {} }
    else
      return { "Data.Generic.Rep∷Sum.Inr", x0[2] }
    end
  end
}
local Golden_BugListGenericEq_Test_eqList
Golden_BugListGenericEq_Test_eqList = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        local _S_cse0 = { "Data.Generic.Rep∷Sum.Inl", {} }
        local v_S_0 = (function()
          if "Golden.BugListGenericEq.Test∷List.Nil" == x[1] then
            return _S_cse0
          else
            return { "Data.Generic.Rep∷Sum.Inr", x[2] }
          end
        end)()
        local v1_S_0 = (function()
          if "Golden.BugListGenericEq.Test∷List.Nil" == y[1] then
            return _S_cse0
          else
            return { "Data.Generic.Rep∷Sum.Inr", y[2] }
          end
        end)()
        local _S_cse1 = v1_S_0[1]
        local _S_cse2 = v_S_0[1]
        if "Data.Generic.Rep∷Sum.Inl" == _S_cse2 then
          return "Data.Generic.Rep∷Sum.Inl" == _S_cse1
        else
          return "Data.Generic.Rep∷Sum.Inr" == _S_cse2 and ("Data.Generic.Rep∷Sum.Inr" == _S_cse1 and (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
            eqRecord = function()
              return function() return function() return true end end
            end
          }, nil, {
            reflectSymbol = function() return "tail" end
          }, Golden_BugListGenericEq_Test_eqList(dictEq)), nil, {
            reflectSymbol = function() return "head" end
          }, dictEq)).eqRecord(Type_Proxy_Proxy)(v_S_0[2])(v1_S_0[2]))
        end
      end
    end
  }
end
local Golden_BugListGenericEq_Test_eq = (Golden_BugListGenericEq_Test_eqList({
  eq = function(r1_S_0) return function(r2_S_0) return r1_S_0 == r2_S_0 end end
})).eq
local Golden_BugListGenericEq_Test_cons_S_w = function(head, tail)
  return {
    "Golden.BugListGenericEq.Test∷List.Cons",
    { head = head, tail = tail }
  }
end
return (function()
  local _ = Effect_Console_log((function()
    if Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_Nil)(Golden_BugListGenericEq_Test_Nil) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil)))(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil))) then
      return "true"
    else
      return "false"
    end
  end)())()
  return Effect_Console_log((function()
    if Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_cons_S_w(1, Golden_BugListGenericEq_Test_Nil))(Golden_BugListGenericEq_Test_cons_S_w(2, Golden_BugListGenericEq_Test_Nil)) then
      return "true"
    else
      return "false"
    end
  end)())()
end)()
