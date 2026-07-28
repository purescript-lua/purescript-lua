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
local Data_Unit_unit = {}
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
local Effect_pureE = Effect_foreign.pureE
local Effect_bindEffect
local Effect_applicativeEffect
local Effect_monadEffect = {
  Applicative0 = function() return Effect_applicativeEffect end,
  Bind1 = function() return Effect_bindEffect end
}
local Effect_Lazy_applyEffect
Effect_bindEffect = {
  bind = Effect_foreign.bindE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
Effect_applicativeEffect = {
  pure = Effect_pureE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
local Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_0)
      return function(a_S_0)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_0))(a_S_0)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_0 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_1)
        return function(a_S_1)
          return bind_S_0(f_S_1)(function(fPrime_S_0)
            return bind_S_0(a_S_1)(function(aPrime_S_0)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_0(aPrime_S_0))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
return {
  baz = (function()
    local Bind1_S_0 = Effect_monadEffect.Bind1()
    local pure_S_0 = (Effect_monadEffect.Applicative0()).pure
    local f_S_2 = Effect_pureE(Data_Unit_unit)
    return Bind1_S_0.bind(f_S_2)(function()
      return Bind1_S_0.bind(pure_S_0({
        [1] = (function()
          local Bind1_S_1 = Effect_monadEffect.Bind1()
          local fn1_S_0 = f_S_2
          return Bind1_S_1.bind(fn1_S_0)(function()
            return Bind1_S_1.bind(fn1_S_0)(function()
              return Bind1_S_1.bind(fn1_S_0)(function() return fn1_S_0 end)
            end)
          end)
        end)()
      }))(function() return pure_S_0(Data_Unit_unit) end)
    end)
  end)()
}
