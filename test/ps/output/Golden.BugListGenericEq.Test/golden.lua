local M = {}
local Record_Unsafe_foreign = {
  unsafeGet = function(l) return function(r) return r[l] end end
}
local Record_Unsafe_unsafeGet = Record_Unsafe_foreign.unsafeGet
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
        local _S_cse1 = v1_S_0[2]
        local _S_cse2 = v_S_0[2]
        local _S_cse3 = Data_HeytingAlgebra_heytingAlgebraBoolean.conj
        local _S_cse4 = v1_S_0[1]
        local _S_cse5 = v_S_0[1]
        if "Data.Generic.Rep∷Sum.Inl" == _S_cse5 then
          return "Data.Generic.Rep∷Sum.Inl" == _S_cse4
        else
          return "Data.Generic.Rep∷Sum.Inr" == _S_cse5 and ("Data.Generic.Rep∷Sum.Inr" == _S_cse4 and (function(  )
            local key_S_0 = "head"
            local get_S_0 = Record_Unsafe_unsafeGet(key_S_0)
            return _S_cse3(dictEq.eq(get_S_0(_S_cse2))(get_S_0(_S_cse1)))((function(  )
              local key_S_1 = "tail"
              local get_S_1 = Record_Unsafe_unsafeGet(key_S_1)
              return _S_cse3((Golden_BugListGenericEq_Test_eqList(dictEq)).eq(get_S_1(_S_cse2))(get_S_1(_S_cse1)))(true)
            end)())
          end)())
        end
      end
    end
  }
end
local Golden_BugListGenericEq_Test_eq = (Golden_BugListGenericEq_Test_eqList({
  eq = function(r1_S_0) return function(r2_S_0) return r1_S_0 == r2_S_0 end end
})).eq
return (function()
  local _S_cse6 = {
    "Golden.BugListGenericEq.Test∷List.Cons",
    { head = 2, tail = Golden_BugListGenericEq_Test_Nil }
  }
  local _S_cse7 = {
    "Golden.BugListGenericEq.Test∷List.Cons",
    { head = 1, tail = _S_cse6 }
  }
  local _ = Effect_Console_log((function()
    if Golden_BugListGenericEq_Test_eq(Golden_BugListGenericEq_Test_Nil)(Golden_BugListGenericEq_Test_Nil) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Golden_BugListGenericEq_Test_eq(_S_cse7)(_S_cse7) then
      return "true"
    else
      return "false"
    end
  end)())()
  return Effect_Console_log((function()
    if Golden_BugListGenericEq_Test_eq({
      "Golden.BugListGenericEq.Test∷List.Cons",
      { head = 1, tail = Golden_BugListGenericEq_Test_Nil }
    })(_S_cse6) then
      return "true"
    else
      return "false"
    end
  end)())()
end)()
