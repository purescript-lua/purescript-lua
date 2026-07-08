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
M.Data_Unit_foreign = { unit = {} }
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_FloatIn_Test_foreign = {
  tick = function(n) print("tick") return n + n end
}
M.Data_Semiring_semiringInt = {
  add = function(x_S_192)
    return function(y_S_193) return x_S_192 + y_S_193 end
  end,
  zero = 0,
  mul = function(x_S_190)
    return function(y_S_191) return x_S_190 * y_S_191 end
  end,
  one = 1
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
    map = function(f_S_28)
      return function(a_S_29)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_28))(a_S_29)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_7 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_9)
        return function(a_S_10)
          return bind_S_7(f_S_9)(function(fPrime_S_11)
            return bind_S_7(a_S_10)(function(aPrime_S_12)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_11(aPrime_S_12))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_FloatIn_Test_add = M.Data_Semiring_semiringInt.add
M.Golden_FloatIn_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_FloatIn_Test_logShow = function(a_S_2)
  return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(a_S_2))
end
M.Golden_FloatIn_Test_pickShared_S_w = function(useIt, n)
  if useIt then
    local shared = M.Golden_FloatIn_Test_foreign.tick(n)
    local f = function() return M.Golden_FloatIn_Test_add(shared)(shared) end
    return M.Golden_FloatIn_Test_add(f(M.Data_Unit_foreign.unit))(f(M.Data_Unit_foreign.unit))
  else
    return 0
  end
end
M.Golden_FloatIn_Test_expensive = function(x)
  return M.Golden_FloatIn_Test_add(M.Data_Semiring_semiringInt.mul(x)(x))(1)
end
M.Golden_FloatIn_Test_pick_S_w = function(useIt, n)
  if useIt then
    local shared = M.Golden_FloatIn_Test_expensive(n)
    return M.Golden_FloatIn_Test_add(shared)(shared)
  else
    return 0
  end
end
return (function()
  local Golden_FloatIn_Test_logShow, Golden_FloatIn_Test_pickShared_S_w, Golden_FloatIn_Test_pick_S_w = M.Golden_FloatIn_Test_logShow, M.Golden_FloatIn_Test_pickShared_S_w, M.Golden_FloatIn_Test_pick_S_w
  local _ = Golden_FloatIn_Test_logShow(Golden_FloatIn_Test_pick_S_w(true, 3))()
  local _ = Golden_FloatIn_Test_logShow(Golden_FloatIn_Test_pick_S_w(false, 3))()
  local _ = Golden_FloatIn_Test_logShow(Golden_FloatIn_Test_pickShared_S_w(true, 3))()
  return Golden_FloatIn_Test_logShow(Golden_FloatIn_Test_pickShared_S_w(false, 3))()
end)()
