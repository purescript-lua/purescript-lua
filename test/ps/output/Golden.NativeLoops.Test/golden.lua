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
local Data_Unit_unit = {}
local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end,
  whileE = function(f)
    return function(a) return function() while f() do a() end end end
  end,
  forE = function(lo)
    return function(hi)
      return function(f)
        return function() for i = lo, hi - 1 do f(i)() end end
      end
    end
  end,
  foreachE = function(as)
    return function(f)
      return function() for i = 1, #(as) do f(as[i])() end end
    end
  end
}
M.Effect_forE = Effect_foreign.forE
M.Effect_foreachE = Effect_foreign.foreachE
local Effect_Console_log = function(s) return function() print(s) end end
local Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
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
local Effect_Ref__new = Effect_Ref_foreign._new
local Effect_Ref_modifyImpl = Effect_Ref_foreign.modifyImpl
local Effect_Ref_read = Effect_Ref_foreign.read
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
local Effect_functorEffect = Effect_Lazy_functorEffect(0)
local Golden_NativeLoops_Test_logShow = function(a_S_2)
  return Effect_Console_log(Data_Show_showIntImpl(a_S_2))
end
return (function()
  local _ = Effect_Console_log("forE:")()
  do
    local _S_f0 = Golden_NativeLoops_Test_logShow
    for _S_i0 = 1, 3 do _S_f0(_S_i0)() end
  end
  local _ = Effect_Console_log("foreachE:")()
  local sum_S_0 = Effect_Ref__new(0)()
  do
    local _S_xs0 = { [1] = 10, [2] = 20, [3] = 30 }
    for _S_i1 = 1, #(_S_xs0) do
      local n_S_0 = _S_xs0[_S_i1]
      Effect_functorEffect.map(function()
        return Data_Unit_unit
      end)(Effect_Ref_modifyImpl(function(s_S_0)
        local sPrime_S_0 = s_S_0 + n_S_0
        return { state = sPrime_S_0, value = sPrime_S_0 }
      end)(sum_S_0))()
    end
  end
  local total_S_0 = Effect_Ref_read(sum_S_0)()
  local _ = Effect_Console_log(Data_Show_showIntImpl(total_S_0))()
  local _ = Effect_Console_log("whileE:")()
  local counter_S_0 = Effect_Ref__new(0)()
  do
    local _S_cond0 = Effect_functorEffect.map(function(v0_S_0)
      return v0_S_0 < 3
    end)(Effect_Ref_read(counter_S_0))
    while _S_cond0() do
      local n0_S_0 = Effect_Ref_read(counter_S_0)()
      local _ = Effect_Console_log(Data_Show_showIntImpl(n0_S_0))()
      Effect_functorEffect.map(function()
        return Data_Unit_unit
      end)(Effect_Ref_modifyImpl(function(s_S_1)
        local sPrime_S_1 = s_S_1 + 1
        return { state = sPrime_S_1, value = sPrime_S_1 }
      end)(counter_S_0))()
    end
  end
  local _ = Effect_Console_log("nested:")()
  for i_S_0 = 0, 1 do
    do
      local _S_xs1 = { [1] = "x", [2] = "y" }
      for _S_i2 = 1, #(_S_xs1) do
        local s_S_2 = _S_xs1[_S_i2]
        Effect_Console_log(Data_Show_showIntImpl(i_S_0) .. s_S_2)()
      end
    end
  end
end)()
