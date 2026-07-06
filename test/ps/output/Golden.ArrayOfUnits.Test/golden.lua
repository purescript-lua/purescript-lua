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
M.Data_Unit_foreign = { unit = {} }
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end,
  intMul = function(x) return function(y) return x * y end end
}
M.Data_Foldable_foreign = {
  foldrArray = function(f)
      return function(init)
        return function(xs)
          local acc = init
          local len = #xs
          for i = len, 1, -1 do acc = f(xs[i])(acc) end
          return acc
        end
      end
    end,
  foldlArray = function(f)
      return function(init)
        return function(xs)
          local acc = init
          local len = #xs
          for i = 1, len do acc = f(acc)(xs[i]) end
          return acc
        end
      end
    end
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
M.Control_Apply_apply = function(dict) return dict.apply end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Foldable_foldr = function(dict) return dict.foldr end
M.Data_Foldable_foldableArray = {
  foldr = M.Data_Foldable_foreign.foldrArray,
  foldl = M.Data_Foldable_foreign.foldlArray,
  foldMap = function(dictMonoid)
    return function(f_S_884)
      return M.Data_Foldable_foldr(M.Data_Foldable_foldableArray)(function( x_S_885 )
        return function(acc_S_886)
          return (dictMonoid.Semigroup0()).append(f_S_884(x_S_885))(acc_S_886)
        end
      end)(dictMonoid.mempty)
    end
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
    map = function(f_S_707)
      return function(a_S_708)
        return M.Control_Apply_apply(M.Effect_applicativeEffect.Apply0())(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_707))(a_S_708)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_687 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_689)
        return function(a_S_690)
          return bind_S_687(f_S_689)(function(fPrime_S_691)
            return bind_S_687(a_S_690)(function(aPrime_S_692)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_691(aPrime_S_692))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Effect_Console_logShow = function(dictShow)
  return function(a)
    return (function(s) return function() print(s) end end)(dictShow.show(a))
  end
end
return (function()
  local arr_S_0 = {
    [1] = M.Data_Unit_foreign.unit,
    [2] = M.Data_Unit_foreign.unit,
    [3] = M.Data_Unit_foreign.unit
  }
  return function()
    local _ = M.Data_Foldable_foldr(M.Data_Foldable_foldableArray)(function( x_S_907 )
      return (function()
        local dictApply_S_892 = M.Effect_applicativeEffect.Apply0()
        return function(a_S_893)
          return function(b_S_894)
            return M.Control_Apply_apply(dictApply_S_892)((dictApply_S_892.Functor0()).map(function(  )
              return function(x_S_901) return x_S_901 end
            end)(a_S_893))(b_S_894)
          end
        end
      end)()(M.Effect_Console_logShow({
        show = function() return "unit" end
      })(x_S_907))
    end)(M.Control_Applicative_pure(M.Effect_applicativeEffect)(M.Data_Unit_foreign.unit))(arr_S_0)()
    return M.Effect_Console_logShow({
      show = function(n) return tostring(n) end
    })(M.Data_Foldable_foldableArray.foldl(function(c_S_372_S_881)
      return function()
        return M.Data_Semiring_semiringInt.add(M.Data_Semiring_semiringInt.one)(c_S_372_S_881)
      end
    end)(M.Data_Semiring_semiringInt.zero)(arr_S_0))()
  end
end)()()
