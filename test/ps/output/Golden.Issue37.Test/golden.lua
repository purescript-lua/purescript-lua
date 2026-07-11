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
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
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
    map = function(f_S_32)
      return function(a_S_33)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_32))(a_S_33)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_11 = (M.Effect_monadEffect.Bind1()).bind
      return function(f_S_13)
        return function(a_S_14)
          return bind_S_11(f_S_13)(function(fPrime_S_15)
            return bind_S_11(a_S_14)(function(aPrime_S_16)
              return (M.Effect_monadEffect.Applicative0()).pure(fPrime_S_15(aPrime_S_16))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
return {
  baz = (function()
    local Effect_monadEffect = M.Effect_monadEffect
    local Bind1_S_1 = Effect_monadEffect.Bind1()
    local pure_S_4 = (Effect_monadEffect.Applicative0()).pure
    return function(f_S_6)
      return Bind1_S_1.bind(f_S_6)(function()
        return Bind1_S_1.bind(pure_S_4({
          [1] = (function()
            local Bind1_S_216 = M.Effect_monadEffect.Bind1()
            return function(fn1_S_218)
              return Bind1_S_216.bind(fn1_S_218)(function()
                return Bind1_S_216.bind(fn1_S_218)(function()
                  return Bind1_S_216.bind(fn1_S_218)(function()
                    return fn1_S_218
                  end)
                end)
              end)
            end
          end)()(f_S_6)
        }))(function() return pure_S_4(M.Data_Unit_foreign.unit) end)
      end)
    end
  end)()(M.Effect_applicativeEffect.pure(M.Data_Unit_foreign.unit))
}
