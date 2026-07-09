local M = {}
M.Record_Unsafe_foreign = {
  unsafeGet = function(l) return function(r) return r[l] end end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Type_Proxy_Proxy = {}
M.Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      local Data_HeytingAlgebra_heytingAlgebraBoolean = M.Data_HeytingAlgebra_heytingAlgebraBoolean
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
M.Data_Eq_eqInt = {
  eq = function(r1_S_213)
    return function(r2_S_214) return r1_S_213 == r2_S_214 end
  end
}
M.Data_Eq_eqRowCons_S_w = function( dictEqRecord
, eqRowCons_S_u2
, dictIsSymbol
, dictEq )
  return {
    eqRecord = function()
      return function(ra)
        return function(rb)
          local Type_Proxy_Proxy = M.Type_Proxy_Proxy
          local key = dictIsSymbol.reflectSymbol(Type_Proxy_Proxy)
          local get = M.Record_Unsafe_foreign.unsafeGet(key)
          return M.Data_HeytingAlgebra_heytingAlgebraBoolean.conj(dictEq.eq(get(ra))(get(rb)))(dictEqRecord.eqRecord(Type_Proxy_Proxy)(ra)(rb))
        end
      end
    end
  }
end
M.Data_Generic_Rep_Inl = function(value0)
  return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inl", value0 = value0 }
end
M.Data_Generic_Rep_Inr = function(value0)
  return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inr", value0 = value0 }
end
M.Data_Generic_Rep_NoArguments = {}
M.Golden_GenericEqTwoTypes_Test_Leaf = {
  ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷Tree.Leaf"
}
M.Golden_GenericEqTwoTypes_Test_Node = function(value0)
  return {
    ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷Tree.Node",
    value0 = value0
  }
end
M.Golden_GenericEqTwoTypes_Test_Nil = {
  ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷List.Nil"
}
M.Golden_GenericEqTwoTypes_Test_Cons = function(value0)
  return {
    ["$ctor"] = "Golden.GenericEqTwoTypes.Test∷List.Cons",
    value0 = value0
  }
end
M.Golden_GenericEqTwoTypes_Test_node_S_w = function(left, value, right)
  return M.Golden_GenericEqTwoTypes_Test_Node({
    left = left,
    value = value,
    right = right
  })
end
M.Golden_GenericEqTwoTypes_Test_genericTree = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x["$ctor"] then
      return M.Golden_GenericEqTwoTypes_Test_Leaf
    elseif "Data.Generic.Rep∷Sum.Inr" == x["$ctor"] then
      return M.Golden_GenericEqTwoTypes_Test_Node(x.value0)
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    if "Golden.GenericEqTwoTypes.Test∷Tree.Leaf" == x0["$ctor"] then
      return M.Data_Generic_Rep_Inl(M.Data_Generic_Rep_NoArguments)
    elseif "Golden.GenericEqTwoTypes.Test∷Tree.Node" == x0["$ctor"] then
      return M.Data_Generic_Rep_Inr(x0.value0)
    else
      return error("No patterns matched")
    end
  end
}
M.Golden_GenericEqTwoTypes_Test_genericList = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x["$ctor"] then
      return M.Golden_GenericEqTwoTypes_Test_Nil
    elseif "Data.Generic.Rep∷Sum.Inr" == x["$ctor"] then
      return M.Golden_GenericEqTwoTypes_Test_Cons(x.value0)
    else
      return error("No patterns matched")
    end
  end,
  from = function(x0)
    if "Golden.GenericEqTwoTypes.Test∷List.Nil" == x0["$ctor"] then
      return M.Data_Generic_Rep_Inl(M.Data_Generic_Rep_NoArguments)
    elseif "Golden.GenericEqTwoTypes.Test∷List.Cons" == x0["$ctor"] then
      return M.Data_Generic_Rep_Inr(x0.value0)
    else
      return error("No patterns matched")
    end
  end
}
M.Golden_GenericEqTwoTypes_Test_eqTree = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return (function()
          local from_S_271 = function(x0_S_275)
            if "Golden.GenericEqTwoTypes.Test∷Tree.Leaf" == x0_S_275["$ctor"] then
              return M.Data_Generic_Rep_Inl(M.Data_Generic_Rep_NoArguments)
            elseif "Golden.GenericEqTwoTypes.Test∷Tree.Node" == x0_S_275["$ctor"] then
              return M.Data_Generic_Rep_Inr(x0_S_275.value0)
            else
              return error("No patterns matched")
            end
          end
          return function(dictGenericEq_S_272)
            return function(x_S_273)
              return function(y_S_274)
                return dictGenericEq_S_272.genericEqPrime(from_S_271(x_S_273))(from_S_271(y_S_274))
              end
            end
          end
        end)()({
          genericEqPrime = function(v_S_7_S_290)
            return function(v1_S_8_S_291)
              if "Data.Generic.Rep∷Sum.Inl" == v_S_7_S_290["$ctor"] then
                return "Data.Generic.Rep∷Sum.Inl" == v1_S_8_S_291["$ctor"]
              elseif "Data.Generic.Rep∷Sum.Inr" == v_S_7_S_290["$ctor"] then
                if "Data.Generic.Rep∷Sum.Inr" == v1_S_8_S_291["$ctor"] then
                  return (M.Data_Eq_eqRowCons_S_w(M.Data_Eq_eqRowCons_S_w(M.Data_Eq_eqRowCons_S_w({
                    eqRecord = function()
                      return function() return function() return true end end
                    end
                  }, nil, {
                    reflectSymbol = function() return "value" end
                  }, dictEq), nil, {
                    reflectSymbol = function() return "right" end
                  }, M.Golden_GenericEqTwoTypes_Test_eqTree(dictEq)), nil, {
                    reflectSymbol = function() return "left" end
                  }, M.Golden_GenericEqTwoTypes_Test_eqTree(dictEq))).eqRecord(M.Type_Proxy_Proxy)(v_S_7_S_290.value0)(v1_S_8_S_291.value0)
                else
                  return false
                end
              else
                return false
              end
            end
          end
        })(x)(y)
      end
    end
  }
end
M.Golden_GenericEqTwoTypes_Test_eq = (M.Golden_GenericEqTwoTypes_Test_eqTree(M.Data_Eq_eqInt)).eq
M.Golden_GenericEqTwoTypes_Test_eqList = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return (function()
          local from_S_242 = function(x0_S_246)
            if "Golden.GenericEqTwoTypes.Test∷List.Nil" == x0_S_246["$ctor"] then
              return M.Data_Generic_Rep_Inl(M.Data_Generic_Rep_NoArguments)
            elseif "Golden.GenericEqTwoTypes.Test∷List.Cons" == x0_S_246["$ctor"] then
              return M.Data_Generic_Rep_Inr(x0_S_246.value0)
            else
              return error("No patterns matched")
            end
          end
          return function(dictGenericEq_S_243)
            return function(x_S_244)
              return function(y_S_245)
                return dictGenericEq_S_243.genericEqPrime(from_S_242(x_S_244))(from_S_242(y_S_245))
              end
            end
          end
        end)()({
          genericEqPrime = function(v_S_7_S_261)
            return function(v1_S_8_S_262)
              if "Data.Generic.Rep∷Sum.Inl" == v_S_7_S_261["$ctor"] then
                return "Data.Generic.Rep∷Sum.Inl" == v1_S_8_S_262["$ctor"]
              elseif "Data.Generic.Rep∷Sum.Inr" == v_S_7_S_261["$ctor"] then
                if "Data.Generic.Rep∷Sum.Inr" == v1_S_8_S_262["$ctor"] then
                  return (M.Data_Eq_eqRowCons_S_w(M.Data_Eq_eqRowCons_S_w({
                    eqRecord = function()
                      return function() return function() return true end end
                    end
                  }, nil, {
                    reflectSymbol = function() return "tail" end
                  }, M.Golden_GenericEqTwoTypes_Test_eqList(dictEq)), nil, {
                    reflectSymbol = function() return "head" end
                  }, dictEq)).eqRecord(M.Type_Proxy_Proxy)(v_S_7_S_261.value0)(v1_S_8_S_262.value0)
                else
                  return false
                end
              else
                return false
              end
            end
          end
        })(x)(y)
      end
    end
  }
end
M.Golden_GenericEqTwoTypes_Test_eq1 = (M.Golden_GenericEqTwoTypes_Test_eqList(M.Data_Eq_eqInt)).eq
M.Golden_GenericEqTwoTypes_Test_cons_S_w = function(head, tail)
  return M.Golden_GenericEqTwoTypes_Test_Cons({ head = head, tail = tail })
end
return (function()
  local Golden_GenericEqTwoTypes_Test_Leaf, Golden_GenericEqTwoTypes_Test_cons_S_w, Golden_GenericEqTwoTypes_Test_node_S_w, Effect_Console_foreign, Golden_GenericEqTwoTypes_Test_Nil, Golden_GenericEqTwoTypes_Test_eq, Golden_GenericEqTwoTypes_Test_eq1 = M.Golden_GenericEqTwoTypes_Test_Leaf, M.Golden_GenericEqTwoTypes_Test_cons_S_w, M.Golden_GenericEqTwoTypes_Test_node_S_w, M.Effect_Console_foreign, M.Golden_GenericEqTwoTypes_Test_Nil, M.Golden_GenericEqTwoTypes_Test_eq, M.Golden_GenericEqTwoTypes_Test_eq1
  local _ = (function()
    local a_S_2_S_314 = Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_314 then
        return "true"
      elseif false == a_S_2_S_314 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_315 = Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_Nil))(Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_315 then
        return "true"
      elseif false == a_S_2_S_315 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_316 = Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_316 then
        return "true"
      elseif false == a_S_2_S_316 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_2_S_317 = Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_Leaf))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf))
    return Effect_Console_foreign.log((function()
      if a_S_2_S_317 then
        return "true"
      elseif false == a_S_2_S_317 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
