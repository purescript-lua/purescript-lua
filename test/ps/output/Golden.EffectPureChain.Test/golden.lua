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
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
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
  pure = Effect_foreign.pureE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
local Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_29)
      return function(a_S_30)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_29))(a_S_30)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_8 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_10)
        return function(a_S_11)
          return bind_S_8(f_S_10)(function(fPrime_S_12)
            return bind_S_8(a_S_11)(function(aPrime_S_13)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_12(aPrime_S_13))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
local Golden_EffectPureChain_Test_append_S_w = function( s1_S_195_S_217
, s2_S_196_S_218 )
  return s1_S_195_S_217 .. s2_S_196_S_218
end
local Golden_EffectPureChain_Test_show = Data_Show_showIntImpl
local Golden_EffectPureChain_Test_pure = Effect_applicativeEffect.pure
M.Golden_EffectPureChain_Test_count = function(n)
  return function()
    local _ = Effect_Console_log(Golden_EffectPureChain_Test_append_S_w("counting from ", Golden_EffectPureChain_Test_show(n)))()
    local x = Golden_EffectPureChain_Test_pure(n + 1)()
    local _ = Effect_Console_log(Golden_EffectPureChain_Test_append_S_w("got ", Golden_EffectPureChain_Test_show(x)))()
    local y = Golden_EffectPureChain_Test_pure(x * 2)()
    return Golden_EffectPureChain_Test_pure(x + y)()
  end
end
return (function()
  local total_S_0 = (function()
    local _ = Effect_Console_log(Golden_EffectPureChain_Test_append_S_w("counting from ", Golden_EffectPureChain_Test_show(20)))()
    local x = Golden_EffectPureChain_Test_pure(21)()
    local _ = Effect_Console_log(Golden_EffectPureChain_Test_append_S_w("got ", Golden_EffectPureChain_Test_show(x)))()
    local y = Golden_EffectPureChain_Test_pure(x * 2)()
    return Golden_EffectPureChain_Test_pure(x + y)()
  end)()
  return Effect_Console_log(Data_Show_showIntImpl(total_S_0))()
end)()
