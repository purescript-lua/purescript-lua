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
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a) return function(f) return function() return f(a())() end end end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Maybe_Nothing = { ["$ctor"] = "Data.Maybe∷Maybe.Nothing" }
M.Data_Maybe_Just = function(value0)
  return { ["$ctor"] = "Data.Maybe∷Maybe.Just", value0 = value0 }
end
M.Data_Maybe_maybe = function(v)
  return function(v1)
    return function(v2)
      if "Data.Maybe∷Maybe.Nothing" == v2["$ctor"] then
        return v
      else
        if "Data.Maybe∷Maybe.Just" == v2["$ctor"] then
          return v1(v2.value0)
        else
          return error("No patterns matched")
        end
      end
    end
  end
end
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
    map = function(f_S_121)
      return function(a_S_122)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_121))(a_S_122)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_101 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_103)
        return function(a_S_104)
          return bind_S_101(f_S_103)(function(fPrime_S_105)
            return bind_S_101(a_S_104)(function(aPrime_S_106)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_105(aPrime_S_106))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_MaybeChain_Test_logShow = function(a_S_4)
  return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(a_S_4))
end
M.Golden_MaybeChain_Test_identity = function(x_S_280) return x_S_280 end
M.Golden_MaybeChain_Test_map = function(v_S_275)
  return function(v1_S_276)
    if "Data.Maybe∷Maybe.Just" == v1_S_276["$ctor"] then
      return M.Data_Maybe_Just(v_S_275(v1_S_276.value0))
    else
      return M.Data_Maybe_Nothing
    end
  end
end
return (function()
  local _ = M.Golden_MaybeChain_Test_logShow(M.Data_Maybe_maybe(0)(M.Golden_MaybeChain_Test_identity)(M.Data_Maybe_maybe(M.Data_Maybe_Nothing)(M.Data_Maybe_Just)(M.Golden_MaybeChain_Test_map(function( x_S_0 )
    return x_S_0
  end)(M.Data_Maybe_Nothing))))()
  return M.Golden_MaybeChain_Test_logShow(M.Data_Maybe_maybe(0)(M.Golden_MaybeChain_Test_identity)(M.Data_Maybe_maybe(M.Data_Maybe_Nothing)(M.Data_Maybe_Just)(M.Golden_MaybeChain_Test_map(function( x0_S_1 )
    return x0_S_1
  end)(M.Data_Maybe_Just(42)))))()
end)()
