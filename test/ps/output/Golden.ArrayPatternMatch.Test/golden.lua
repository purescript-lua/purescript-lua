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
M.Data_Ring_ringInt = {
  sub = function(x) return function(y) return x - y end end,
  Semiring0 = function() return M.Data_Semiring_semiringInt end
}
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
    map = function(f_S_40)
      return function(a_S_41)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_40))(a_S_41)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_17 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_19)
        return function(a_S_20)
          return bind_S_17(f_S_19)(function(fPrime_S_21)
            return bind_S_17(a_S_20)(function(aPrime_S_22)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_21(aPrime_S_22))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_ArrayPatternMatch_Test_negate = function(a_S_165)
  return M.Data_Ring_ringInt.sub((M.Data_Ring_ringInt.Semiring0()).zero)(a_S_165)
end
M.Golden_ArrayPatternMatch_Test_discard = (function(dictBind_S_23_S_1371)
  return M.Control_Bind_bind(dictBind_S_23_S_1371)
end)(M.Effect_bindEffect)
M.Golden_ArrayPatternMatch_Test_logShow = function(a_S_2)
  return (function(s) return function() print(s) end end)((function(n) return tostring(n) end)(a_S_2))
end
M.Golden_ArrayPatternMatch_Test_lastOfThree = function(v)
  if 3 == #(v) then
    return v[3]
  else
    return M.Golden_ArrayPatternMatch_Test_negate(1)
  end
end
M.Golden_ArrayPatternMatch_Test_firstTwo = function(v)
  if 2 == #(v) then
    return M.Data_Semiring_semiringInt.add(v[1])(v[2])
  else
    return M.Golden_ArrayPatternMatch_Test_negate(1)
  end
end
return (function()
  local _ = M.Golden_ArrayPatternMatch_Test_logShow(M.Golden_ArrayPatternMatch_Test_firstTwo({
    [1] = 10,
    [2] = 20
  }))()
  local _ = M.Golden_ArrayPatternMatch_Test_logShow(M.Golden_ArrayPatternMatch_Test_firstTwo({
    [1] = 1,
    [2] = 2,
    [3] = 3
  }))()
  local _ = M.Golden_ArrayPatternMatch_Test_logShow(M.Golden_ArrayPatternMatch_Test_firstTwo({}))()
  return M.Golden_ArrayPatternMatch_Test_logShow(M.Golden_ArrayPatternMatch_Test_lastOfThree({
    [1] = 7,
    [2] = 8,
    [3] = 9
  }))()
end)()
