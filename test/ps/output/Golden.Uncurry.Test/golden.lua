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
M.Data_Eq_foreign = (function()
  local refEq = function(r1) return function(r2) return r1 == r2 end end
  return { eqIntImpl = refEq }
end)()
M.Data_Show_foreign = {
  showIntImpl = function(n) return tostring(n) end,
  showArrayImpl = function(f)
    return function(xs)
      local l = #(xs)
      local ss = {}
      for i = 1, l do ss[i] = f(xs[i]) end
      return "[" .. table.concat(ss, ",") .. "]"
    end
  end
}
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end
}
M.Data_Ring_foreign = {
  intSub = function(x) return function(y) return x - y end end
}
M.Data_Functor_foreign = {
  arrayMap = function(f)
    return function(arr)
      local l = #(arr)
      local result = {}
      for i = 1, l do result[i] = f(arr[i]) end
      return result
    end
  end
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
M.Data_Show_showInt = { show = M.Data_Show_foreign.showIntImpl }
M.Data_Show_show = function(dict) return dict.show end
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
    map = function(f_S_26)
      return function(a_S_27)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_26))(a_S_27)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_5 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_7)
        return function(a_S_8)
          return bind_S_5(f_S_7)(function(fPrime_S_9)
            return bind_S_5(a_S_8)(function(aPrime_S_10)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_9(aPrime_S_10))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Effect_Console_logShow_S_w = function(dictShow, a)
  return M.Effect_Console_foreign.log(M.Data_Show_show(dictShow)(a))
end
M.Golden_Uncurry_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_Uncurry_Test_logShow = function(logShow_S_p2_S_188)
  return M.Effect_Console_logShow_S_w(M.Data_Show_showInt, logShow_S_p2_S_188)
end
M.Golden_Uncurry_Test_sumTo = function(m)
  local go_S_w
  go_S_w = function(acc, n)
    local Data_Eq_foreign, Data_Ring_foreign, Data_Semiring_foreign = M.Data_Eq_foreign, M.Data_Ring_foreign, M.Data_Semiring_foreign
    while true do
      if Data_Eq_foreign.eqIntImpl(n)(0) then
        return acc
      else
        acc, n = Data_Semiring_foreign.intAdd(acc)(n), Data_Ring_foreign.intSub(n)(1)
      end
    end
  end
  return go_S_w(0, m)
end
M.Golden_Uncurry_Test_oddSteps_S_w = function(acc, n)
  if M.Data_Eq_foreign.eqIntImpl(n)(0) then
    return acc
  else
    return M.Golden_Uncurry_Test_evenSteps_S_w(M.Data_Semiring_foreign.intAdd(acc)(1), M.Data_Ring_foreign.intSub(n)(1))
  end
end
M.Golden_Uncurry_Test_oddSteps = function(oddSteps_S_p1)
  return function(oddSteps_S_p2)
    return M.Golden_Uncurry_Test_oddSteps_S_w(oddSteps_S_p1, oddSteps_S_p2)
  end
end
M.Golden_Uncurry_Test_evenSteps_S_w = function(acc, n)
  if M.Data_Eq_foreign.eqIntImpl(n)(0) then
    return acc
  else
    return M.Golden_Uncurry_Test_oddSteps_S_w(M.Data_Semiring_foreign.intAdd(acc)(1), M.Data_Ring_foreign.intSub(n)(1))
  end
end
M.Golden_Uncurry_Test_evenSteps = function(evenSteps_S_p1)
  return function(evenSteps_S_p2)
    return M.Golden_Uncurry_Test_evenSteps_S_w(evenSteps_S_p1, evenSteps_S_p2)
  end
end
M.Golden_Uncurry_Test_alwaysFirst_S_w = function(x) return x end
M.Golden_Uncurry_Test_adderOf_S_w = function(x, y)
  local Data_Semiring_foreign = M.Data_Semiring_foreign
  return Data_Semiring_foreign.intAdd(Data_Semiring_foreign.intAdd(x)(y))
end
M.Golden_Uncurry_Test_add3_S_w = function(x, y, z)
  local Data_Semiring_foreign = M.Data_Semiring_foreign
  return Data_Semiring_foreign.intAdd(Data_Semiring_foreign.intAdd(x)(y))(z)
end
M.Golden_Uncurry_Test_add3 = function(add3_S_p1)
  return function(add3_S_p2)
    return function(add3_S_p3)
      return M.Golden_Uncurry_Test_add3_S_w(add3_S_p1, add3_S_p2, add3_S_p3)
    end
  end
end
M.Golden_Uncurry_Test_inc = M.Golden_Uncurry_Test_add3(1)(0)
return (function()
  local Golden_Uncurry_Test_logShow, Golden_Uncurry_Test_add3_S_w, Golden_Uncurry_Test_adderOf_S_w, Golden_Uncurry_Test_alwaysFirst_S_w, Golden_Uncurry_Test_sumTo = M.Golden_Uncurry_Test_logShow, M.Golden_Uncurry_Test_add3_S_w, M.Golden_Uncurry_Test_adderOf_S_w, M.Golden_Uncurry_Test_alwaysFirst_S_w, M.Golden_Uncurry_Test_sumTo
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_add3_S_w(1, 2, 3))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_add3_S_w(4, 5, 6))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_add3_S_w(10, 1, 2))()
  local _ = Golden_Uncurry_Test_logShow(M.Golden_Uncurry_Test_inc(41))()
  local _ = M.Effect_Console_logShow_S_w({
    show = M.Data_Show_foreign.showArrayImpl(M.Data_Show_show(M.Data_Show_showInt))
  }, M.Data_Functor_foreign.arrayMap(M.Golden_Uncurry_Test_add3(1)(2))({
    [1] = 1,
    [2] = 2,
    [3] = 3
  }))()
  local _ = Golden_Uncurry_Test_logShow(M.Golden_Uncurry_Test_evenSteps_S_w(0, 10))()
  local _ = Golden_Uncurry_Test_logShow(M.Golden_Uncurry_Test_oddSteps_S_w(0, 7))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_sumTo(10))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_sumTo(100))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_adderOf_S_w(1, 2)(3))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_adderOf_S_w(2, 3)(4))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_alwaysFirst_S_w(7, 8))()
  return Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_alwaysFirst_S_w(9, 10))()
end)()
