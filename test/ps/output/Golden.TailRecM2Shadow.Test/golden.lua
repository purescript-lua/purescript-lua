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
  end,
  untilE = function(f) return function() while not(f()) do  end end end
}
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
  pure = Effect_foreign.pureE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
local Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_239)
      return function(a_S_240)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_239))(a_S_240)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_219 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_221)
        return function(a_S_222)
          return bind_S_219(f_S_221)(function(fPrime_S_223)
            return bind_S_219(a_S_222)(function(aPrime_S_224)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_223(aPrime_S_224))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
local Effect_functorEffect = Effect_Lazy_functorEffect(0)
local Control_Monad_Rec_Class_pure = Effect_applicativeEffect.pure
local Golden_TailRecM2Shadow_Test_add_S_w = function( x_S_457_S_491
, y_S_458_S_492 )
  return x_S_457_S_491 + y_S_458_S_492
end
M.Golden_TailRecM2Shadow_Test_sumFrom = function(dictMonadRec)
  local pure = ((dictMonadRec.Monad0()).Applicative0()).pure
  return function(b)
    return function(n)
      return dictMonadRec.tailRecM(function(o_S_483)
        if "Data.Ordering∷Ordering.LT" == (function()
          if o_S_483.b < n then
            return "Data.Ordering∷Ordering.LT"
          elseif o_S_483.b == n then
            return "Data.Ordering∷Ordering.EQ"
          else
            return "Data.Ordering∷Ordering.GT"
          end
        end)() then
          return pure((function(value0)
            return { "Control.Monad.Rec.Class∷Step.Loop", value0 }
          end)({
            a = Golden_TailRecM2Shadow_Test_add_S_w(o_S_483.a, o_S_483.b),
            b = Golden_TailRecM2Shadow_Test_add_S_w(o_S_483.b, 1)
          }))
        else
          return pure((function(value0)
            return { "Control.Monad.Rec.Class∷Step.Done", value0 }
          end)(o_S_483.a))
        end
      end)({ a = b, b = 0 })
    end
  end
end
return (function()
  local r_S_0 = (function()
    local dictMonadRec_S_535 = {
      tailRecM = function(f_S_11)
        return function(a_S_12)
          return function()
            local r_S_16 = Effect_bindEffect.bind(f_S_11(a_S_12))(Effect_Ref_foreign._new)()
            local _ = Effect_foreign.untilE(function()
              local v0_S_17 = Effect_Ref_read(r_S_16)()
              return (function()
                if "Control.Monad.Rec.Class∷Step.Loop" == v0_S_17[1] then
                  return function()
                    local e_S_19 = f_S_11(v0_S_17[2])()
                    local _ = Effect_Ref_foreign.write(e_S_19)(r_S_16)()
                    return Control_Monad_Rec_Class_pure(false)()
                  end
                elseif "Control.Monad.Rec.Class∷Step.Done" == v0_S_17[1] then
                  return Control_Monad_Rec_Class_pure(true)
                else
                  return error("No patterns matched")
                end
              end)()()
            end)()
            return Effect_functorEffect.map(Partial_Unsafe_foreign._unsafePartial(function(  )
              return function(v_S_9_S_20)
                if "Control.Monad.Rec.Class∷Step.Done" == v_S_9_S_20[1] then
                  return v_S_9_S_20[2]
                else
                  return error("No patterns matched")
                end
              end
            end))(Effect_Ref_read(r_S_16))()
          end
        end
      end,
      Monad0 = function() return Effect_monadEffect end
    }
    local pure_S_536 = ((dictMonadRec_S_535.Monad0()).Applicative0()).pure
    return function(b_S_537)
      return function(n_S_538)
        return dictMonadRec_S_535.tailRecM(function(o_S_483_S_539)
          if "Data.Ordering∷Ordering.LT" == (function()
            if o_S_483_S_539.b < n_S_538 then
              return "Data.Ordering∷Ordering.LT"
            elseif o_S_483_S_539.b == n_S_538 then
              return "Data.Ordering∷Ordering.EQ"
            else
              return "Data.Ordering∷Ordering.GT"
            end
          end)() then
            return pure_S_536((function(value0)
              return { "Control.Monad.Rec.Class∷Step.Loop", value0 }
            end)({
              a = Golden_TailRecM2Shadow_Test_add_S_w(o_S_483_S_539.a, o_S_483_S_539.b),
              b = Golden_TailRecM2Shadow_Test_add_S_w(o_S_483_S_539.b, 1)
            }))
          else
            return pure_S_536((function(value0)
              return { "Control.Monad.Rec.Class∷Step.Done", value0 }
            end)(o_S_483_S_539.a))
          end
        end)({ a = b_S_537, b = 0 })
      end
    end
  end)()(0)(5)()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(r_S_0))()
end)()
