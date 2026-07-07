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
    map = function(f_S_32)
      return function(a_S_33)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_32))(a_S_33)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_11 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_13)
        return function(a_S_14)
          return bind_S_11(f_S_13)(function(fPrime_S_15)
            return bind_S_11(a_S_14)(function(aPrime_S_16)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_15(aPrime_S_16))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_Issue37_Test_discard = function(dictBind_S_17_S_186)
  return M.Control_Bind_bind(dictBind_S_17_S_186)
end
return {
  baz = (function()
    local Effect_monadEffect = M.Effect_monadEffect
    local Bind1_S_1 = Effect_monadEffect.Bind1()
    local pure_S_4 = M.Control_Applicative_pure(Effect_monadEffect.Applicative0())
    return function(f_S_6)
      return M.Golden_Issue37_Test_discard(Bind1_S_1)(f_S_6)(function()
        return M.Control_Bind_bind(Bind1_S_1)(pure_S_4({
          [1] = (function()
            local Bind1_S_183 = M.Effect_monadEffect.Bind1()
            local discard1_S_184 = M.Golden_Issue37_Test_discard(Bind1_S_183)
            return function(fn1_S_185)
              return M.Control_Bind_bind(M.Effect_monadEffect.Bind1())(fn1_S_185)(function(  )
                return discard1_S_184(fn1_S_185)(function()
                  return discard1_S_184(fn1_S_185)(function()
                    return fn1_S_185
                  end)
                end)
              end)
            end
          end)()(f_S_6)
        }))(function() return pure_S_4(M.Data_Unit_foreign.unit) end)
      end)
    end
  end)()(M.Control_Applicative_pure(M.Effect_applicativeEffect)(M.Data_Unit_foreign.unit))
}
