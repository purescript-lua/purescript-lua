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
  conj = function(b1_S_217)
    return function(b2_S_218) return b1_S_217 and b2_S_218 end
  end,
  disj = function(b1_S_215)
    return function(b2_S_216) return b1_S_215 or b2_S_216 end
  end,
  _not_ = function(b_S_214) return not(b_S_214) end
}
local Data_Eq_eqInt = {
  eq = function(r1_S_210)
    return function(r2_S_211) return r1_S_210 == r2_S_211 end
  end
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
local Data_Generic_Rep_NoArguments = {}
local Data_Eq_Generic_genericEq_S_w = function(dictGeneric, dictGenericEq, x, y)
  local _S_cse303 = dictGeneric.from
  return dictGenericEq.genericEqPrime(_S_cse303(x))(_S_cse303(y))
end
local Golden_GenericEqTwoTypes_Test_Leaf = {
  "Golden.GenericEqTwoTypes.Test∷Tree.Leaf"
}
M.Golden_GenericEqTwoTypes_Test_Node = function(value0)
  return { "Golden.GenericEqTwoTypes.Test∷Tree.Node", value0 }
end
local Golden_GenericEqTwoTypes_Test_Nil = {
  "Golden.GenericEqTwoTypes.Test∷List.Nil"
}
M.Golden_GenericEqTwoTypes_Test_Cons = function(value0)
  return { "Golden.GenericEqTwoTypes.Test∷List.Cons", value0 }
end
local Golden_GenericEqTwoTypes_Test_node_S_w = function(left, value, right)
  return {
    "Golden.GenericEqTwoTypes.Test∷Tree.Node",
    { left = left, value = value, right = right }
  }
end
local Golden_GenericEqTwoTypes_Test_genericTree = {
  to = function(x)
    local _S_cse304 = x[1]
    if "Data.Generic.Rep∷Sum.Inl" == _S_cse304 then
      return Golden_GenericEqTwoTypes_Test_Leaf
    elseif "Data.Generic.Rep∷Sum.Inr" == _S_cse304 then
      return { "Golden.GenericEqTwoTypes.Test∷Tree.Node", x[2] }
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    local _S_cse305 = x0[1]
    if "Golden.GenericEqTwoTypes.Test∷Tree.Leaf" == _S_cse305 then
      return { "Data.Generic.Rep∷Sum.Inl", Data_Generic_Rep_NoArguments }
    elseif "Golden.GenericEqTwoTypes.Test∷Tree.Node" == _S_cse305 then
      return { "Data.Generic.Rep∷Sum.Inr", x0[2] }
    else
      return error("No patterns matched")
    end
  end
}
local Golden_GenericEqTwoTypes_Test_genericList = {
  to = function(x)
    local _S_cse306 = x[1]
    if "Data.Generic.Rep∷Sum.Inl" == _S_cse306 then
      return Golden_GenericEqTwoTypes_Test_Nil
    elseif "Data.Generic.Rep∷Sum.Inr" == _S_cse306 then
      return { "Golden.GenericEqTwoTypes.Test∷List.Cons", x[2] }
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    local _S_cse307 = x0[1]
    if "Golden.GenericEqTwoTypes.Test∷List.Nil" == _S_cse307 then
      return { "Data.Generic.Rep∷Sum.Inl", Data_Generic_Rep_NoArguments }
    elseif "Golden.GenericEqTwoTypes.Test∷List.Cons" == _S_cse307 then
      return { "Data.Generic.Rep∷Sum.Inr", x0[2] }
    else
      return error("No patterns matched")
    end
  end
}
local Golden_GenericEqTwoTypes_Test_eqTree
Golden_GenericEqTwoTypes_Test_eqTree = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return Data_Eq_Generic_genericEq_S_w(Golden_GenericEqTwoTypes_Test_genericTree, {
          genericEqPrime = function(v_S_272)
            return function(v1_S_273)
              local _S_cse309 = v1_S_273[1]
              local _S_cse308 = v_S_272[1]
              if "Data.Generic.Rep∷Sum.Inl" == _S_cse308 then
                return "Data.Generic.Rep∷Sum.Inl" == _S_cse309
              else
                return "Data.Generic.Rep∷Sum.Inr" == _S_cse308 and ("Data.Generic.Rep∷Sum.Inr" == _S_cse309 and (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
                  eqRecord = function()
                    return function() return function() return true end end
                  end
                }, nil, {
                  reflectSymbol = function() return "value" end
                }, dictEq), nil, {
                  reflectSymbol = function() return "right" end
                }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq)), nil, {
                  reflectSymbol = function() return "left" end
                }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq))).eqRecord(Type_Proxy_Proxy)(v_S_272[2])(v1_S_273[2]))
              end
            end
          end
        }, x, y)
      end
    end
  }
end
local Golden_GenericEqTwoTypes_Test_eq = (Golden_GenericEqTwoTypes_Test_eqTree(Data_Eq_eqInt)).eq
local Golden_GenericEqTwoTypes_Test_eqList
Golden_GenericEqTwoTypes_Test_eqList = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return Data_Eq_Generic_genericEq_S_w(Golden_GenericEqTwoTypes_Test_genericList, {
          genericEqPrime = function(v_S_250)
            return function(v1_S_251)
              local _S_cse311 = v1_S_251[1]
              local _S_cse310 = v_S_250[1]
              if "Data.Generic.Rep∷Sum.Inl" == _S_cse310 then
                return "Data.Generic.Rep∷Sum.Inl" == _S_cse311
              else
                return "Data.Generic.Rep∷Sum.Inr" == _S_cse310 and ("Data.Generic.Rep∷Sum.Inr" == _S_cse311 and (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
                  eqRecord = function()
                    return function() return function() return true end end
                  end
                }, nil, {
                  reflectSymbol = function() return "tail" end
                }, Golden_GenericEqTwoTypes_Test_eqList(dictEq)), nil, {
                  reflectSymbol = function() return "head" end
                }, dictEq)).eqRecord(Type_Proxy_Proxy)(v_S_250[2])(v1_S_251[2]))
              end
            end
          end
        }, x, y)
      end
    end
  }
end
local Golden_GenericEqTwoTypes_Test_eq1 = (Golden_GenericEqTwoTypes_Test_eqList(Data_Eq_eqInt)).eq
local Golden_GenericEqTwoTypes_Test_cons_S_w = function(head, tail)
  return {
    "Golden.GenericEqTwoTypes.Test∷List.Cons",
    { head = head, tail = tail }
  }
end
return (function()
  local _ = (function()
    local a_S_299 = Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))
    return Effect_Console_log((function()
      if a_S_299 then
        return "true"
      elseif false == a_S_299 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_300 = Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_Nil))(Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil))
    return Effect_Console_log((function()
      if a_S_300 then
        return "true"
      elseif false == a_S_300 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_301 = Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))
    return Effect_Console_log((function()
      if a_S_301 then
        return "true"
      elseif false == a_S_301 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_302 = Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_Leaf))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf))
    return Effect_Console_log((function()
      if a_S_302 then
        return "true"
      elseif false == a_S_302 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
