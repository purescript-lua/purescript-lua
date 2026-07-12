local Record_Unsafe_foreign = {
  unsafeGet = function(l) return function(r) return r[l] end end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
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
  conj = function(b1_S_220)
    return function(b2_S_221) return b1_S_220 and b2_S_221 end
  end,
  disj = function(b1_S_218)
    return function(b2_S_219) return b1_S_218 or b2_S_219 end
  end,
  _not_ = function(b_S_217) return not(b_S_217) end
}
local Data_Eq_eqInt = {
  eq = function(r1_S_213)
    return function(r2_S_214) return r1_S_213 == r2_S_214 end
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
local Data_Generic_Rep_Inl = function(value0)
  return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inl", value0 = value0 }
end
local Data_Generic_Rep_Inr = function(value0)
  return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inr", value0 = value0 }
end
local Data_Generic_Rep_NoArguments = {}
local Data_Eq_Generic_genericEq_S_w = function(dictGeneric, dictGenericEq, x, y)
  return dictGenericEq.genericEqPrime(dictGeneric.from(x))(dictGeneric.from(y))
end
local Golden_GenericEqTwoTypes_Test_Leaf = {
  ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷Tree.Leaf"
}
local Golden_GenericEqTwoTypes_Test_Node = function(value0)
  return {
    ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷Tree.Node",
    value0 = value0
  }
end
local Golden_GenericEqTwoTypes_Test_Nil = {
  ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷List.Nil"
}
local Golden_GenericEqTwoTypes_Test_Cons = function(value0)
  return {
    ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷List.Cons",
    value0 = value0
  }
end
local Golden_GenericEqTwoTypes_Test_node_S_w = function(left, value, right)
  return Golden_GenericEqTwoTypes_Test_Node({
    left = left,
    value = value,
    right = right
  })
end
local Golden_GenericEqTwoTypes_Test_genericTree = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x["$ctor"] then
      return Golden_GenericEqTwoTypes_Test_Leaf
    elseif "Data.Generic.Rep∷Sum.Inr" == x["$ctor"] then
      return Golden_GenericEqTwoTypes_Test_Node(x.value0)
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    if "Golden.GenericEqTwoTypes.Test∷Tree.Leaf" == x0["$ctor"] then
      return Data_Generic_Rep_Inl(Data_Generic_Rep_NoArguments)
    elseif "Golden.GenericEqTwoTypes.Test∷Tree.Node" == x0["$ctor"] then
      return Data_Generic_Rep_Inr(x0.value0)
    else
      return error("No patterns matched")
    end
  end
}
local Golden_GenericEqTwoTypes_Test_genericList = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x["$ctor"] then
      return Golden_GenericEqTwoTypes_Test_Nil
    elseif "Data.Generic.Rep∷Sum.Inr" == x["$ctor"] then
      return Golden_GenericEqTwoTypes_Test_Cons(x.value0)
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    if "Golden.GenericEqTwoTypes.Test∷List.Nil" == x0["$ctor"] then
      return Data_Generic_Rep_Inl(Data_Generic_Rep_NoArguments)
    elseif "Golden.GenericEqTwoTypes.Test∷List.Cons" == x0["$ctor"] then
      return Data_Generic_Rep_Inr(x0.value0)
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
          genericEqPrime = function(v_S_7_S_276)
            return function(v1_S_8_S_277)
              if "Data.Generic.Rep∷Sum.Inl" == v_S_7_S_276["$ctor"] then
                return "Data.Generic.Rep∷Sum.Inl" == v1_S_8_S_277["$ctor"]
              elseif "Data.Generic.Rep∷Sum.Inr" == v_S_7_S_276["$ctor"] then
                if "Data.Generic.Rep∷Sum.Inr" == v1_S_8_S_277["$ctor"] then
                  return (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
                    eqRecord = function()
                      return function() return function() return true end end
                    end
                  }, nil, {
                    reflectSymbol = function() return "value" end
                  }, dictEq), nil, {
                    reflectSymbol = function() return "right" end
                  }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq)), nil, {
                    reflectSymbol = function() return "left" end
                  }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq))).eqRecord(Type_Proxy_Proxy)(v_S_7_S_276.value0)(v1_S_8_S_277.value0)
                else
                  return false
                end
              else
                return false
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
          genericEqPrime = function(v_S_7_S_254)
            return function(v1_S_8_S_255)
              if "Data.Generic.Rep∷Sum.Inl" == v_S_7_S_254["$ctor"] then
                return "Data.Generic.Rep∷Sum.Inl" == v1_S_8_S_255["$ctor"]
              elseif "Data.Generic.Rep∷Sum.Inr" == v_S_7_S_254["$ctor"] then
                if "Data.Generic.Rep∷Sum.Inr" == v1_S_8_S_255["$ctor"] then
                  return (Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w({
                    eqRecord = function()
                      return function() return function() return true end end
                    end
                  }, nil, {
                    reflectSymbol = function() return "tail" end
                  }, Golden_GenericEqTwoTypes_Test_eqList(dictEq)), nil, {
                    reflectSymbol = function() return "head" end
                  }, dictEq)).eqRecord(Type_Proxy_Proxy)(v_S_7_S_254.value0)(v1_S_8_S_255.value0)
                else
                  return false
                end
              else
                return false
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
  return Golden_GenericEqTwoTypes_Test_Cons({ head = head, tail = tail })
end
return (function()
  local _ = (function()
    local a_S_2_S_300 = Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_300 then
        return "true"
      elseif false == a_S_2_S_300 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_301 = Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_Nil))(Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_301 then
        return "true"
      elseif false == a_S_2_S_301 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_302 = Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_302 then
        return "true"
      elseif false == a_S_2_S_302 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_2_S_303 = Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_Leaf))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_303 then
        return "true"
      elseif false == a_S_2_S_303 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
