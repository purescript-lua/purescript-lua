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
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
local Control_Monad_ST_Internal_foreign = {
  map_ = function(f)
    return function(a) return function() return f(a()) end end
  end,
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end,
  new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  modifyImpl = function(f)
    return function(ref)
      return function()
        local t = f(ref.value)
        ref.value = t.state
        return t.value
      end
    end
  end
}
local Control_Monad_ST_Internal_modifyImpl = Control_Monad_ST_Internal_foreign.modifyImpl
local Control_Monad_ST_Internal_new = Control_Monad_ST_Internal_foreign.new
local Control_Monad_ST_Internal_read = Control_Monad_ST_Internal_foreign.read
local Control_Monad_ST_Internal_run = Control_Monad_ST_Internal_foreign.run
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
    map = function(f_S_219)
      return function(a_S_220)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_219))(a_S_220)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_471 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_472)
        return function(a_S_473)
          return bind_S_471(f_S_472)(function(fPrime_S_474)
            return bind_S_471(a_S_473)(function(aPrime_S_475)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_474(aPrime_S_475))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
local Control_Monad_ST_Internal_bindST
local Control_Monad_ST_Internal_applicativeST
local Control_Monad_ST_Internal_monadST = {
  Applicative0 = function() return Control_Monad_ST_Internal_applicativeST end,
  Bind1 = function() return Control_Monad_ST_Internal_bindST end
}
local Control_Monad_ST_Internal_Lazy_applyST
Control_Monad_ST_Internal_bindST = {
  bind = Control_Monad_ST_Internal_foreign.bind_,
  Apply0 = function() return Control_Monad_ST_Internal_Lazy_applyST(0) end
}
Control_Monad_ST_Internal_applicativeST = {
  pure = Control_Monad_ST_Internal_foreign.pure_,
  Apply0 = function() return Control_Monad_ST_Internal_Lazy_applyST(0) end
}
Control_Monad_ST_Internal_Lazy_applyST = PSLUA_runtime_lazy("applyST")(function(  )
  return {
    apply = (function()
      local bind_S_462 = (Control_Monad_ST_Internal_monadST.Bind1()).bind
      return function(f_S_463)
        return function(a_S_464)
          return bind_S_462(f_S_463)(function(fPrime_S_465)
            return bind_S_462(a_S_464)(function(aPrime_S_466)
              return (Control_Monad_ST_Internal_monadST.Applicative0()).pure(fPrime_S_465(aPrime_S_466))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return { map = Control_Monad_ST_Internal_foreign.map_ }
    end
  }
end)
M.Golden_MixedEffectSTDo_Test_tally = function(start)
  return Control_Monad_ST_Internal_run(function()
    local ref = Control_Monad_ST_Internal_new(start)()
    local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_8)
      local sPrime_S_9 = s_S_8 * 2
      return { state = sPrime_S_9, value = sPrime_S_9 }
    end)(ref)()
    local n = Control_Monad_ST_Internal_read(ref)()
    return Control_Monad_ST_Internal_applicativeST.pure(n + 3)()
  end)
end
return (function()
  local _ = Effect_Console_log("mixing Effect and ST")()
  local x_S_0 = Effect_applicativeEffect.pure(Control_Monad_ST_Internal_run(function(  )
    local ref_S_482 = Control_Monad_ST_Internal_new(2)()
    local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_8_S_484)
      local sPrime_S_9_S_485 = s_S_8_S_484 * 2
      return { state = sPrime_S_9_S_485, value = sPrime_S_9_S_485 }
    end)(ref_S_482)()
    local n_S_483 = Control_Monad_ST_Internal_read(ref_S_482)()
    return Control_Monad_ST_Internal_applicativeST.pure(n_S_483 + 3)()
  end))()
  local _ = Effect_Console_log(Data_Show_foreign.showIntImpl(x_S_0))()
  return Effect_Console_log("done")()
end)()
