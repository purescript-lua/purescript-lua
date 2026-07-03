local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      else
        if state == 1 then
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
end
local M = {}
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end,
  intMul = function(x) return function(y) return x * y end end
}
M.Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a) return function(f) return function() return f(a())() end end end
}
M.Data_Semiring_semiringInt = {
  add = M.Data_Semiring_foreign.intAdd,
  zero = 0,
  mul = M.Data_Semiring_foreign.intMul,
  one = 1
}
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Newtype_unwrap = function()
  return M.Unsafe_Coerce_foreign.unsafeCoerce
end
M.Data_Profunctor_composeFlipped = function(f_S_1530)
  return function(g_S_1531)
    return (function(f_S_1536)
      return function(g_S_1537)
        return function(x_S_1538) return f_S_1536(g_S_1537(x_S_1538)) end
      end
    end)(g_S_1531)(f_S_1530)
  end
end
M.Data_Profunctor_profunctorFn = {
  dimap = function(a2b)
    return function(c2d)
      return function(b2c)
        return M.Data_Profunctor_composeFlipped(a2b)(M.Data_Profunctor_composeFlipped(b2c)(c2d))
      end
    end
  end
}
M.Data_Profunctor_dimap = function(dict) return dict.dimap end
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
    map = function(f_S_201)
      return function(a_S_202)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_201))(a_S_202)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_178 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_180)
        return function(a_S_181)
          return bind_S_178(f_S_180)(function(fPrime_S_182)
            return bind_S_178(a_S_181)(function(aPrime_S_183)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_182(aPrime_S_183))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_ProfunctorDictLens_Test_unwrap = M.Data_Newtype_unwrap()
M.Golden_ProfunctorDictLens_Test_discard = (function(dictBind_S_184_S_1532)
  return M.Control_Bind_bind(dictBind_S_184_S_1532)
end)(M.Effect_bindEffect)
M.Golden_ProfunctorDictLens_Test_logShow = function(a_S_5)
  return (function(s) return function() print(s) end end)((function(n) return tostring(n) end)(a_S_5))
end
M.Golden_ProfunctorDictLens_Test_Wrapped = function(x) return x end
M.Golden_ProfunctorDictLens_Test__Wrapped = function(dictProfunctor)
  return M.Data_Profunctor_dimap(dictProfunctor)(M.Golden_ProfunctorDictLens_Test_unwrap)(M.Golden_ProfunctorDictLens_Test_Wrapped)
end
M.Golden_ProfunctorDictLens_Test__Wrapped1 = M.Golden_ProfunctorDictLens_Test__Wrapped(M.Data_Profunctor_profunctorFn)
return (function()
  local _ = M.Golden_ProfunctorDictLens_Test_logShow(M.Golden_ProfunctorDictLens_Test_unwrap(M.Golden_ProfunctorDictLens_Test__Wrapped1(function( v_S_0 )
    return M.Data_Semiring_semiringInt.add(v_S_0)(1)
  end)(10)))()
  local _ = M.Golden_ProfunctorDictLens_Test_logShow(M.Golden_ProfunctorDictLens_Test_unwrap(M.Golden_ProfunctorDictLens_Test__Wrapped1(function( v0_S_1 )
    return M.Data_Semiring_semiringInt.mul(v0_S_1)(2)
  end)(10)))()
  return M.Golden_ProfunctorDictLens_Test_logShow(M.Golden_ProfunctorDictLens_Test_unwrap(M.Data_Profunctor_dimap(M.Data_Profunctor_profunctorFn)(M.Data_Newtype_unwrap())(M.Unsafe_Coerce_foreign.unsafeCoerce)(function( v1_S_2 )
    return (function(x) return function(y) return x - y end end)(v1_S_2)(5)
  end)(10)))()
end)()
