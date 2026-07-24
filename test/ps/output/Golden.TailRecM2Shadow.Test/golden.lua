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
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end,
  untilE = function(f) return function() while not(f()) do  end end end
}
local Effect_bindE = Effect_foreign.bindE
local Effect_pureE = Effect_foreign.pureE
local Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  write = function(val)
    return function(ref) return function() ref.value = val end end
  end
}
local Effect_Ref_read = Effect_Ref_foreign.read
local Partial_Unsafe_foreign = { _unsafePartial = function(f) return f() end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_bindEffect
local Effect_applicativeEffect
local Effect_monadEffect = {
  Applicative0 = function() return Effect_applicativeEffect end,
  Bind1 = function() return Effect_bindEffect end
}
local Effect_Lazy_applyEffect
Effect_bindEffect = {
  bind = Effect_bindE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
Effect_applicativeEffect = {
  pure = Effect_pureE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
local Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_238)
      return function(a_S_239)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_pureE(f_S_238))(a_S_239)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_221 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_223)
        return function(a_S_224)
          return bind_S_221(f_S_223)(function(fPrime_S_225)
            return bind_S_221(a_S_224)(function(aPrime_S_226)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_225(aPrime_S_226))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
local Effect_functorEffect = Effect_Lazy_functorEffect(0)
local Golden_TailRecM2Shadow_Test_sumFrom = function(dictMonadRec)
  local pure = ((dictMonadRec.Monad0()).Applicative0()).pure
  return function(b)
    return function(n)
      return dictMonadRec.tailRecM(function(o_S_482)
        local _S_cse532 = o_S_482.a
        local _S_cse531 = o_S_482.b
        if _S_cse531 < n then
          return pure({
            "Control.Monad.Rec.Class∷Step.Loop",
            { a = _S_cse532 + _S_cse531, b = _S_cse531 + 1 }
          })
        else
          return pure({ "Control.Monad.Rec.Class∷Step.Done", _S_cse532 })
        end
      end)({ a = b, b = 0 })
    end
  end
end
return (function()
  local r_S_0 = Golden_TailRecM2Shadow_Test_sumFrom({
    tailRecM = function(f_S_11)
      return function(a_S_12)
        return function()
          local r_S_16 = Effect_bindE(f_S_11(a_S_12))(Effect_Ref_foreign._new)()
          local _ = Effect_foreign.untilE(function()
            local v0_S_17 = Effect_Ref_read(r_S_16)()
            if "Control.Monad.Rec.Class∷Step.Loop" == v0_S_17[1] then
              return (function()
                local e_S_19 = f_S_11(v0_S_17[2])()
                local _ = Effect_Ref_foreign.write(e_S_19)(r_S_16)()
                return false
              end)()
            else
              return Effect_pureE(true)()
            end
          end)()
          return Effect_functorEffect.map(Partial_Unsafe_foreign._unsafePartial(function(  )
            return function(v_S_20)
              if "Control.Monad.Rec.Class∷Step.Done" == v_S_20[1] then
                return v_S_20[2]
              else
                return error("No patterns matched")
              end
            end
          end))(Effect_Ref_read(r_S_16))()
        end
      end
    end,
    Monad0 = function() return Effect_monadEffect end
  })(0)(5)()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(r_S_0))()
end)()
