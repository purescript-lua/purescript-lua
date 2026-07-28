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
  bind = Effect_foreign.bindE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
Effect_applicativeEffect = {
  pure = Effect_pureE,
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
local Golden_TailRecM2Shadow_Test_sumFrom = function(dictMonadRec)
  local pure = ((dictMonadRec.Monad0()).Applicative0()).pure
  return function(b)
    return function(n)
      return dictMonadRec.tailRecM(function(o_S_0)
        local _S_cse0 = o_S_0.a
        local _S_cse1 = o_S_0.b
        if _S_cse1 < n then
          return pure({
            "Control.Monad.Rec.Class∷Step.Loop",
            { a = _S_cse0 + _S_cse1, b = _S_cse1 + 1 }
          })
        else
          return pure({ "Control.Monad.Rec.Class∷Step.Done", _S_cse0 })
        end
      end)({ a = b, b = 0 })
    end
  end
end
return (function()
  local r_S_1 = Golden_TailRecM2Shadow_Test_sumFrom({
    tailRecM = function(f_S_2)
      return function(a_S_2)
        return function()
          local r_S_0 = Effect_bindEffect.bind(f_S_2(a_S_2))(Effect_Ref_foreign._new)()
          local _ = Effect_foreign.untilE(function()
            local v0_S_0 = Effect_Ref_read(r_S_0)()
            if "Control.Monad.Rec.Class∷Step.Loop" == v0_S_0[1] then
              return (function()
                local e_S_0 = f_S_2(v0_S_0[2])()
                local _ = Effect_Ref_foreign.write(e_S_0)(r_S_0)()
                return false
              end)()
            else
              return Effect_pureE(true)()
            end
          end)()
          return Effect_functorEffect.map(Partial_Unsafe_foreign._unsafePartial(function(  )
            return function(v_S_0)
              if "Control.Monad.Rec.Class∷Step.Done" == v_S_0[1] then
                return v_S_0[2]
              else
                return error("No patterns matched")
              end
            end
          end))(Effect_Ref_read(r_S_0))()
        end
      end
    end,
    Monad0 = function() return Effect_monadEffect end
  })(0)(5)()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(r_S_1))()
end)()
