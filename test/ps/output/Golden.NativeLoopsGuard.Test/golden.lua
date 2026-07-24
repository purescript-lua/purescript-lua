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
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
local Effect_pureE = Effect_foreign.pureE
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
local Effect_Ref_read = Effect_Ref_foreign.read
local Data_Array_foreign = {
  indexImpl = function(just, nothing, xs, i)
    if i < 0 or i >= #(xs) then return nothing else return just(xs[i + 1]) end
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
  pure = Effect_pureE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
local Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_942)
      return function(a_S_943)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_pureE(f_S_942))(a_S_943)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_1430 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_1431)
        return function(a_S_1432)
          return bind_S_1430(f_S_1431)(function(fPrime_S_1433)
            return bind_S_1430(a_S_1432)(function(aPrime_S_1434)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_1433(aPrime_S_1434))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
local Effect_functorEffect = Effect_Lazy_functorEffect(0)
local Golden_NativeLoopsGuard_Test_when_S_w = function(v_S_1437, v1_S_1438)
  if v_S_1437 then return v1_S_1438 else return Effect_pureE(Data_Unit_unit) end
end
local Golden_NativeLoopsGuard_Test_logShow = function(a_S_6)
  return Effect_Console_log(Data_Show_showIntImpl(a_S_6))
end
local Golden_NativeLoopsGuard_Test_whileE_S_w = function(cond, act)
  return function()
    local b = cond()
    return Golden_NativeLoopsGuard_Test_when_S_w(b, act)()
  end
end
local Golden_NativeLoopsGuard_Test_foreachE_S_w = function(xs, f)
  local v2_S_1427 = Data_Array_foreign.indexImpl(function(value0_S_1428)
    return { "Data.Maybe∷Maybe.Just", value0_S_1428 }
  end, { "Data.Maybe∷Maybe.Nothing" }, xs, 0)
  if "Data.Maybe∷Maybe.Nothing" == v2_S_1427[1] then
    return Effect_pureE(Data_Unit_unit)
  else
    return f(v2_S_1427[2])
  end
end
local Golden_NativeLoopsGuard_Test_forE_S_w = function(lo, hi, f)
  return Golden_NativeLoopsGuard_Test_when_S_w(lo < hi, f(lo))
end
return (function()
  local _ = Golden_NativeLoopsGuard_Test_forE_S_w(1, 5, Golden_NativeLoopsGuard_Test_logShow)()
  local _ = Golden_NativeLoopsGuard_Test_foreachE_S_w({
    [1] = "x",
    [2] = "y"
  }, Effect_Console_log)()
  local r_S_0 = Effect_Ref_foreign._new(3)()
  local _ = Golden_NativeLoopsGuard_Test_whileE_S_w(Effect_functorEffect.map(function( v_S_1 )
    return not(v_S_1 < 0) and v_S_1 ~= 0
  end)(Effect_Ref_read(r_S_0)), function()
    local n_S_2 = Effect_Ref_read(r_S_0)()
    local _ = Effect_Console_log(Data_Show_showIntImpl(n_S_2))()
    return Effect_functorEffect.map(function()
      return Data_Unit_unit
    end)(Effect_Ref_foreign.modifyImpl(function(s_S_761)
      local sPrime_S_762 = s_S_761 - 1
      return { state = sPrime_S_762, value = sPrime_S_762 }
    end)(r_S_0))()
  end)()
  return Effect_Console_log("guard done")()
end)()
