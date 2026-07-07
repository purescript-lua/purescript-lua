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
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end,
  intMul = function(x) return function(y) return x * y end end
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
M.Data_Semiring_semiringInt = {
  add = M.Data_Semiring_foreign.intAdd,
  zero = 0,
  mul = M.Data_Semiring_foreign.intMul,
  one = 1
}
M.Data_Functor_map = function(dict) return dict.map end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
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
    map = function(f_S_31)
      return function(a_S_32)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_31))(a_S_32)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_10 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_12)
        return function(a_S_13)
          return bind_S_10(f_S_12)(function(fPrime_S_14)
            return bind_S_10(a_S_13)(function(aPrime_S_15)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_14(aPrime_S_15))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_DerivedFunctor_Test_add = M.Data_Semiring_semiringInt.add
M.Golden_DerivedFunctor_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_DerivedFunctor_Test_logShow = function(a_S_5)
  return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(a_S_5))
end
M.Golden_DerivedFunctor_Test_Leaf = {
  ["$ctor"] = "Golden.DerivedFunctor.Test∷Tree.Leaf"
}
M.Golden_DerivedFunctor_Test_Node = function(value0)
  return function(value1)
    return function(value2)
      return {
        ["$ctor"] = "Golden.DerivedFunctor.Test∷Tree.Node",
        value0 = value0,
        value1 = value1,
        value2 = value2
      }
    end
  end
end
M.Golden_DerivedFunctor_Test_Left = function(value0)
  return {
    ["$ctor"] = "Golden.DerivedFunctor.Test∷Either.Left",
    value0 = value0
  }
end
M.Golden_DerivedFunctor_Test_Right = function(value0)
  return {
    ["$ctor"] = "Golden.DerivedFunctor.Test∷Either.Right",
    value0 = value0
  }
end
M.Golden_DerivedFunctor_Test_sumTree = function(v)
  if "Golden.DerivedFunctor.Test∷Tree.Leaf" == v["$ctor"] then
    return 0
  elseif "Golden.DerivedFunctor.Test∷Tree.Node" == v["$ctor"] then
    return M.Golden_DerivedFunctor_Test_add(M.Golden_DerivedFunctor_Test_add(M.Golden_DerivedFunctor_Test_sumTree(v.value0))(v.value1))(M.Golden_DerivedFunctor_Test_sumTree(v.value2))
  else
    return error("No patterns matched")
  end
end
M.Golden_DerivedFunctor_Test_functorTree = {
  map = function(f)
    return function(m)
      if "Golden.DerivedFunctor.Test∷Tree.Leaf" == m["$ctor"] then
        return M.Golden_DerivedFunctor_Test_Leaf
      elseif "Golden.DerivedFunctor.Test∷Tree.Node" == m["$ctor"] then
        return M.Golden_DerivedFunctor_Test_Node(M.Data_Functor_map(M.Golden_DerivedFunctor_Test_functorTree)(f)(m.value0))(f(m.value1))(M.Data_Functor_map(M.Golden_DerivedFunctor_Test_functorTree)(f)(m.value2))
      else
        return error("No patterns matched")
      end
    end
  end
}
M.Golden_DerivedFunctor_Test_functorEither = {
  map = function(f)
    return function(m)
      if "Golden.DerivedFunctor.Test∷Either.Left" == m["$ctor"] then
        return M.Golden_DerivedFunctor_Test_Left(m.value0)
      elseif "Golden.DerivedFunctor.Test∷Either.Right" == m["$ctor"] then
        return M.Golden_DerivedFunctor_Test_Right(f(m.value0))
      else
        return error("No patterns matched")
      end
    end
  end
}
M.Golden_DerivedFunctor_Test_map1 = M.Data_Functor_map(M.Golden_DerivedFunctor_Test_functorEither)
M.Golden_DerivedFunctor_Test_fromRight_S_w = function(fallback, v)
  if "Golden.DerivedFunctor.Test∷Either.Left" == v["$ctor"] then
    return fallback
  elseif "Golden.DerivedFunctor.Test∷Either.Right" == v["$ctor"] then
    return v.value0
  else
    return error("No patterns matched")
  end
end
return (function()
  local _ = M.Golden_DerivedFunctor_Test_logShow(M.Golden_DerivedFunctor_Test_fromRight_S_w(0, M.Golden_DerivedFunctor_Test_map1(function( v_S_0 )
    return M.Golden_DerivedFunctor_Test_add(v_S_0)(1)
  end)(M.Golden_DerivedFunctor_Test_Right(41))))()
  local _ = M.Golden_DerivedFunctor_Test_logShow(M.Golden_DerivedFunctor_Test_fromRight_S_w(7, M.Golden_DerivedFunctor_Test_map1(function( v0_S_1 )
    return M.Golden_DerivedFunctor_Test_add(v0_S_1)(1)
  end)(M.Golden_DerivedFunctor_Test_Left("no"))))()
  return M.Golden_DerivedFunctor_Test_logShow(M.Golden_DerivedFunctor_Test_sumTree(M.Data_Functor_map(M.Golden_DerivedFunctor_Test_functorTree)(function( v1_S_2 )
    return M.Data_Semiring_semiringInt.mul(v1_S_2)(2)
  end)(M.Golden_DerivedFunctor_Test_Node(M.Golden_DerivedFunctor_Test_Node(M.Golden_DerivedFunctor_Test_Leaf)(1)(M.Golden_DerivedFunctor_Test_Leaf))(2)(M.Golden_DerivedFunctor_Test_Node(M.Golden_DerivedFunctor_Test_Leaf)(3)(M.Golden_DerivedFunctor_Test_Leaf)))))()
end)()
