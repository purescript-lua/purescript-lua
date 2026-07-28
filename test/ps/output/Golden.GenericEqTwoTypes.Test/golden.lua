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
local Data_Eq_eqInt = {
  eq = function(r1_S_0) return function(r2_S_0) return r1_S_0 == r2_S_0 end end
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
local Data_Eq_Generic_genericEqArgument = function(dictEq)
  return {
    genericEqPrime = function(v)
      return function(v1) return dictEq.eq(v)(v1) end
    end
  }
end
local Data_Eq_Generic_genericEqPrime = function(dict)
  return dict.genericEqPrime
end
local Data_Eq_Generic_genericEqConstructor = function(dictGenericEq)
  return {
    genericEqPrime = function(v)
      return function(v1) return dictGenericEq.genericEqPrime(v)(v1) end
    end
  }
end
local Golden_GenericEqTwoTypes_Test_genericEqSum = function(dictGenericEq1_S_0)
  return {
    genericEqPrime = function(v_S_0)
      return function(v1_S_0)
        local _S_cse0 = v1_S_0[1]
        local _S_cse1 = v_S_0[1]
        if "Data.Generic.Rep∷Sum.Inl" == _S_cse1 then
          return "Data.Generic.Rep∷Sum.Inl" == _S_cse0
        else
          return "Data.Generic.Rep∷Sum.Inr" == _S_cse1 and ("Data.Generic.Rep∷Sum.Inr" == _S_cse0 and dictGenericEq1_S_0.genericEqPrime(v_S_0[2])(v1_S_0[2]))
        end
      end
    end
  }
end
local Golden_GenericEqTwoTypes_Test_eqRec = function(dictEqRecord_S_0)
  return { eq = dictEqRecord_S_0.eqRecord(Type_Proxy_Proxy) }
end
local Golden_GenericEqTwoTypes_Test_eqRowCons_S_w = function( eqRowCons_S_p3_S_0
, eqRowCons_S_p4_S_0 )
  return Data_Eq_eqRowCons_S_w({
    eqRecord = function()
      return function() return function() return true end end
    end
  }, nil, eqRowCons_S_p3_S_0, eqRowCons_S_p4_S_0)
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
local Golden_GenericEqTwoTypes_Test_genericTree = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x[1] then
      return Golden_GenericEqTwoTypes_Test_Leaf
    else
      return { "Golden.GenericEqTwoTypes.Test∷Tree.Node", x[2] }
    end
  end,
  from = function(x0)
    if "Golden.GenericEqTwoTypes.Test∷Tree.Leaf" == x0[1] then
      return { "Data.Generic.Rep∷Sum.Inl", Data_Generic_Rep_NoArguments }
    else
      return { "Data.Generic.Rep∷Sum.Inr", x0[2] }
    end
  end
}
local Golden_GenericEqTwoTypes_Test_genericList = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x[1] then
      return Golden_GenericEqTwoTypes_Test_Nil
    else
      return { "Golden.GenericEqTwoTypes.Test∷List.Cons", x[2] }
    end
  end,
  from = function(x0)
    if "Golden.GenericEqTwoTypes.Test∷List.Nil" == x0[1] then
      return { "Data.Generic.Rep∷Sum.Inl", Data_Generic_Rep_NoArguments }
    else
      return { "Data.Generic.Rep∷Sum.Inr", x0[2] }
    end
  end
}
local Golden_GenericEqTwoTypes_Test_eqTree
Golden_GenericEqTwoTypes_Test_eqTree = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        local _S_cse2 = Golden_GenericEqTwoTypes_Test_genericTree.from
        return Data_Eq_Generic_genericEqPrime(Golden_GenericEqTwoTypes_Test_genericEqSum(Data_Eq_Generic_genericEqConstructor(Data_Eq_Generic_genericEqArgument(Golden_GenericEqTwoTypes_Test_eqRec(Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w(Golden_GenericEqTwoTypes_Test_eqRowCons_S_w({
          reflectSymbol = function() return "value" end
        }, dictEq), nil, {
          reflectSymbol = function() return "right" end
        }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq)), nil, {
          reflectSymbol = function() return "left" end
        }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq)))))))(_S_cse2(x))(_S_cse2(y))
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
        local _S_cse3 = Golden_GenericEqTwoTypes_Test_genericList.from
        return Data_Eq_Generic_genericEqPrime(Golden_GenericEqTwoTypes_Test_genericEqSum(Data_Eq_Generic_genericEqConstructor(Data_Eq_Generic_genericEqArgument(Golden_GenericEqTwoTypes_Test_eqRec(Data_Eq_eqRowCons_S_w(Golden_GenericEqTwoTypes_Test_eqRowCons_S_w({
          reflectSymbol = function() return "tail" end
        }, Golden_GenericEqTwoTypes_Test_eqList(dictEq)), nil, {
          reflectSymbol = function() return "head" end
        }, dictEq))))))(_S_cse3(x))(_S_cse3(y))
      end
    end
  }
end
local Golden_GenericEqTwoTypes_Test_eq1 = (Golden_GenericEqTwoTypes_Test_eqList(Data_Eq_eqInt)).eq
return (function()
  local _S_cse4 = {
    "Golden.GenericEqTwoTypes.Test∷List.Cons",
    { head = 2, tail = Golden_GenericEqTwoTypes_Test_Nil }
  }
  local _S_cse5 = {
    "Golden.GenericEqTwoTypes.Test∷Tree.Node",
    {
      left = Golden_GenericEqTwoTypes_Test_Leaf,
      value = 2,
      right = Golden_GenericEqTwoTypes_Test_Leaf
    }
  }
  local _S_cse6 = {
    "Golden.GenericEqTwoTypes.Test∷List.Cons",
    { head = 1, tail = _S_cse4 }
  }
  local _S_cse7 = {
    "Golden.GenericEqTwoTypes.Test∷Tree.Node",
    { left = Golden_GenericEqTwoTypes_Test_Leaf, value = 1, right = _S_cse5 }
  }
  local _ = Effect_Console_log((function()
    if Golden_GenericEqTwoTypes_Test_eq1(_S_cse6)(_S_cse6) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Golden_GenericEqTwoTypes_Test_eq1({
      "Golden.GenericEqTwoTypes.Test∷List.Cons",
      { head = 1, tail = Golden_GenericEqTwoTypes_Test_Nil }
    })(_S_cse4) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Golden_GenericEqTwoTypes_Test_eq(_S_cse7)(_S_cse7) then
      return "true"
    else
      return "false"
    end
  end)())()
  return Effect_Console_log((function()
    if Golden_GenericEqTwoTypes_Test_eq({
      "Golden.GenericEqTwoTypes.Test∷Tree.Node",
      {
        left = Golden_GenericEqTwoTypes_Test_Leaf,
        value = 1,
        right = Golden_GenericEqTwoTypes_Test_Leaf
      }
    })(_S_cse5) then
      return "true"
    else
      return "false"
    end
  end)())()
end)()
