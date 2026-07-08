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
M.Record_Unsafe_foreign = {
  unsafeGet = function(l) return function(r) return r[l] end end
}
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
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
M.Data_Eq_eqRecord = function(dict) return dict.eqRecord end
M.Data_Eq_eqInt = {
  eq = function(r1_S_213)
    return function(r2_S_214) return r1_S_213 == r2_S_214 end
  end
}
M.Data_Eq_eq = function(dict) return dict.eq end
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
          return M.Data_HeytingAlgebra_heytingAlgebraBoolean.conj(M.Data_Eq_eq(dictEq)(get(ra))(get(rb)))(M.Data_Eq_eqRecord(dictEqRecord)(Type_Proxy_Proxy)(ra)(rb))
        end
      end
    end
  }
end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Generic_Rep_Inl = function(value0)
  return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inl", value0 = value0 }
end
M.Data_Generic_Rep_Inr = function(value0)
  return { ["$ctor"] = "Data.Generic.Rep∷Sum.Inr", value0 = value0 }
end
M.Data_Generic_Rep_NoArguments = {}
M.Data_Eq_Generic_genericEqArgument = function(dictEq)
  return {
    genericEqPrime = function(v)
      return function(v1) return M.Data_Eq_eq(dictEq)(v)(v1) end
    end
  }
end
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
M.Data_Eq_Generic_genericEq = function(dictGeneric)
  local from = dictGeneric.from
  return function(dictGenericEq)
    return function(x)
      return function(y)
        return M.Data_Eq_Generic_genericEqPrime(dictGenericEq)(from(x))(from(y))
      end
    end
  end
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
    map = function(f_S_42)
      return function(a_S_43)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_42))(a_S_43)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_21 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_23)
        return function(a_S_24)
          return bind_S_21(f_S_23)(function(fPrime_S_25)
            return bind_S_21(a_S_24)(function(aPrime_S_26)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_25(aPrime_S_26))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_GenericEqTwoTypes_Test_genericEqSum = function(dictGenericEq1_S_5)
  return {
    genericEqPrime = function(v_S_7)
      return function(v1_S_8)
        if "Data.Generic.Rep∷Sum.Inl" == v_S_7["$ctor"] then
          if "Data.Generic.Rep∷Sum.Inl" == v1_S_8["$ctor"] then
            return M.Data_Eq_Generic_genericEqPrime(M.Data_Eq_Generic_genericEqConstructor({
              genericEqPrime = function() return function() return true end end
            }))(v_S_7.value0)(v1_S_8.value0)
          else
            return false
          end
        elseif "Data.Generic.Rep∷Sum.Inr" == v_S_7["$ctor"] then
          if "Data.Generic.Rep∷Sum.Inr" == v1_S_8["$ctor"] then
            return M.Data_Eq_Generic_genericEqPrime(dictGenericEq1_S_5)(v_S_7.value0)(v1_S_8.value0)
          else
            return false
          end
        else
          return false
        end
      end
    end
  }
end
M.Golden_GenericEqTwoTypes_Test_eqRec = function(dictEqRecord_S_226)
  return { eq = M.Data_Eq_eqRecord(dictEqRecord_S_226)(M.Type_Proxy_Proxy) }
end
M.Golden_GenericEqTwoTypes_Test_eqRowCons = function(eqRowCons_S_p3_S_238)
  return function(eqRowCons_S_p4_S_239)
    return M.Data_Eq_eqRowCons_S_w({
      eqRecord = function()
        return function() return function() return true end end
      end
    }, nil, eqRowCons_S_p3_S_238, eqRowCons_S_p4_S_239)
  end
end
M.Golden_GenericEqTwoTypes_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_GenericEqTwoTypes_Test_logShow = function(a_S_2)
  return M.Effect_Console_foreign.log((function()
    if a_S_2 then
      return "true"
    elseif false == a_S_2 then
      return "false"
    else
      return error("No patterns matched")
    end
  end)())
end
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
        local Data_Eq_eqRowCons_S_w, Golden_GenericEqTwoTypes_Test_eqTree = M.Data_Eq_eqRowCons_S_w, M.Golden_GenericEqTwoTypes_Test_eqTree
        return M.Data_Eq_Generic_genericEq(M.Golden_GenericEqTwoTypes_Test_genericTree)(M.Golden_GenericEqTwoTypes_Test_genericEqSum(M.Data_Eq_Generic_genericEqConstructor(M.Data_Eq_Generic_genericEqArgument(M.Golden_GenericEqTwoTypes_Test_eqRec(Data_Eq_eqRowCons_S_w(Data_Eq_eqRowCons_S_w(M.Golden_GenericEqTwoTypes_Test_eqRowCons({
          reflectSymbol = function() return "value" end
        })(dictEq), nil, {
          reflectSymbol = function() return "right" end
        }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq)), nil, {
          reflectSymbol = function() return "left" end
        }, Golden_GenericEqTwoTypes_Test_eqTree(dictEq)))))))(x)(y)
      end
    end
  }
end
M.Golden_GenericEqTwoTypes_Test_eq = M.Data_Eq_eq(M.Golden_GenericEqTwoTypes_Test_eqTree(M.Data_Eq_eqInt))
M.Golden_GenericEqTwoTypes_Test_eqList = function(dictEq)
  return {
    eq = function(x)
      return function(y)
        return M.Data_Eq_Generic_genericEq(M.Golden_GenericEqTwoTypes_Test_genericList)(M.Golden_GenericEqTwoTypes_Test_genericEqSum(M.Data_Eq_Generic_genericEqConstructor(M.Data_Eq_Generic_genericEqArgument(M.Golden_GenericEqTwoTypes_Test_eqRec(M.Data_Eq_eqRowCons_S_w(M.Golden_GenericEqTwoTypes_Test_eqRowCons({
          reflectSymbol = function() return "tail" end
        })(M.Golden_GenericEqTwoTypes_Test_eqList(dictEq)), nil, {
          reflectSymbol = function() return "head" end
        }, dictEq))))))(x)(y)
      end
    end
  }
end
M.Golden_GenericEqTwoTypes_Test_eq1 = M.Data_Eq_eq(M.Golden_GenericEqTwoTypes_Test_eqList(M.Data_Eq_eqInt))
M.Golden_GenericEqTwoTypes_Test_cons_S_w = function(head, tail)
  return M.Golden_GenericEqTwoTypes_Test_Cons({ head = head, tail = tail })
end
return (function()
  local Golden_GenericEqTwoTypes_Test_Leaf, Golden_GenericEqTwoTypes_Test_cons_S_w, Golden_GenericEqTwoTypes_Test_node_S_w, Golden_GenericEqTwoTypes_Test_Nil, Golden_GenericEqTwoTypes_Test_logShow, Golden_GenericEqTwoTypes_Test_eq, Golden_GenericEqTwoTypes_Test_eq1 = M.Golden_GenericEqTwoTypes_Test_Leaf, M.Golden_GenericEqTwoTypes_Test_cons_S_w, M.Golden_GenericEqTwoTypes_Test_node_S_w, M.Golden_GenericEqTwoTypes_Test_Nil, M.Golden_GenericEqTwoTypes_Test_logShow, M.Golden_GenericEqTwoTypes_Test_eq, M.Golden_GenericEqTwoTypes_Test_eq1
  local _ = Golden_GenericEqTwoTypes_Test_logShow(Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil))))()
  local _ = Golden_GenericEqTwoTypes_Test_logShow(Golden_GenericEqTwoTypes_Test_eq1(Golden_GenericEqTwoTypes_Test_cons_S_w(1, Golden_GenericEqTwoTypes_Test_Nil))(Golden_GenericEqTwoTypes_Test_cons_S_w(2, Golden_GenericEqTwoTypes_Test_Nil)))()
  local _ = Golden_GenericEqTwoTypes_Test_logShow(Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf))))()
  return Golden_GenericEqTwoTypes_Test_logShow(Golden_GenericEqTwoTypes_Test_eq(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 1, Golden_GenericEqTwoTypes_Test_Leaf))(Golden_GenericEqTwoTypes_Test_node_S_w(Golden_GenericEqTwoTypes_Test_Leaf, 2, Golden_GenericEqTwoTypes_Test_Leaf)))()
end)()
