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
local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Foldable_foreign = {
  foldrArray = function(f)
    return function(init)
      return function(xs)
        local acc = init
        local len = #(xs)
        for i = len, 1, -(1) do acc = f(xs[i])(acc) end
        return acc
      end
    end
  end,
  foldlArray = function(f)
    return function(init)
      return function(xs)
        local acc = init
        local len = #(xs)
        for i = 1, len do acc = f(acc)(xs[i]) end
        return acc
      end
    end
  end
}
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
local Effect_pureE = Effect_foreign.pureE
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Foldable_foldableArray
Data_Foldable_foldableArray = {
  foldr = Data_Foldable_foreign.foldrArray,
  foldl = Data_Foldable_foreign.foldlArray,
  foldMap = function(dictMonoid)
    return function(f_S_0)
      return Data_Foldable_foldableArray.foldr(function(x_S_0)
        return function(acc_S_0)
          return (dictMonoid.Semigroup0()).append(f_S_0(x_S_0))(acc_S_0)
        end
      end)(dictMonoid.mempty)
    end
  end
}
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
    map = function(f_S_1)
      return function(a_S_0)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_pureE(f_S_1))(a_S_0)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_0 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_2)
        return function(a_S_1)
          return bind_S_0(f_S_2)(function(fPrime_S_0)
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
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
end
return (function()
  local arr_S_0 = {
    [1] = Data_Unit_unit,
    [2] = Data_Unit_unit,
    [3] = Data_Unit_unit
  }
  local _ = Data_Foldable_foldableArray.foldr(function(x_S_1)
    local dictApply_S_0 = Effect_applicativeEffect.Apply0()
    local a_S_2 = Effect_Console_logShow_S_w({
      show = function() return "unit" end
    }, x_S_1)
    return function(b_S_0)
      return dictApply_S_0.apply((dictApply_S_0.Functor0()).map(function()
        return function(x_S_2) return x_S_2 end
      end)(a_S_2))(b_S_0)
    end
  end)(Effect_pureE(Data_Unit_unit))(arr_S_0)()
  return Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showIntImpl
  }, Data_Foldable_foldableArray.foldl(function(c_S_0)
    return function() return 1 + c_S_0 end
  end)(0)(arr_S_0))()
end)()
