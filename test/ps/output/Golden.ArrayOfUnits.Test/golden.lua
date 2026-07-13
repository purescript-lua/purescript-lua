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
    return function(f_S_914)
      return Data_Foldable_foldableArray.foldr(function(x_S_915)
        return function(acc_S_916)
          return (dictMonoid.Semigroup0()).append(f_S_914(x_S_915))(acc_S_916)
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
    map = function(f_S_704)
      return function(a_S_705)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_pureE(f_S_704))(a_S_705)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_687 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_689)
        return function(a_S_690)
          return bind_S_687(f_S_689)(function(fPrime_S_691)
            return bind_S_687(a_S_690)(function(aPrime_S_692)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_691(aPrime_S_692))
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
  return function()
    local _ = Data_Foldable_foldableArray.foldr(function(x_S_938)
      return (function()
        local dictApply_S_923 = Effect_applicativeEffect.Apply0()
        return function(a_S_924)
          return function(b_S_925)
            return dictApply_S_923.apply((dictApply_S_923.Functor0()).map(function(  )
              return function(x_S_932) return x_S_932 end
            end)(a_S_924))(b_S_925)
          end
        end
      end)()(Effect_Console_logShow_S_w({
        show = function() return "unit" end
      }, x_S_938))
    end)(Effect_pureE(Data_Unit_unit))(arr_S_0)()
    return Effect_Console_logShow_S_w({
      show = Data_Show_foreign.showIntImpl
    }, Data_Foldable_foldableArray.foldl(function(c_S_372_S_911)
      return function() return 1 + c_S_372_S_911 end
    end)(0)(arr_S_0))()
  end
end)()()
