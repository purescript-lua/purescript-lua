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
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end
}
M.Data_Ord_foreign = (function()
  local unsafeCoerceImpl = function(lt)
    return function(eq)
      return function(gt)
        return function(x)
          return function(y)
            if x < y then
              return lt
            elseif x == y then
              return eq
            else
              return gt
            end
          end
        end
      end
    end
  end
  return { ordIntImpl = unsafeCoerceImpl }
end)()
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end,
  untilE = function(f) return function() while not(f()) do  end end end
}
M.Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  write = function(val)
    return function(ref) return function() ref.value = val end end
  end
}
M.Partial_Unsafe_foreign = { _unsafePartial = function(f) return f() end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
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
    map = function(f_S_239)
      return function(a_S_240)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_239))(a_S_240)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_219 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_221)
        return function(a_S_222)
          return bind_S_219(f_S_221)(function(fPrime_S_223)
            return bind_S_219(a_S_222)(function(aPrime_S_224)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_223(aPrime_S_224))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Effect_functorEffect = M.Effect_Lazy_functorEffect(0)
M.Control_Monad_Rec_Class_bind = M.Control_Bind_bind(M.Effect_bindEffect)
M.Control_Monad_Rec_Class_pure = M.Control_Applicative_pure(M.Effect_applicativeEffect)
M.Golden_TailRecM2Shadow_Test_sumFrom = function(dictMonadRec)
  local pure = M.Control_Applicative_pure((dictMonadRec.Monad0()).Applicative0())
  return function(b)
    return function(n)
      return dictMonadRec.tailRecM(function(o_S_450)
        return (function()
          local acc_S_1 = o_S_450.a
          return function(i_S_2)
            if (function()
              if "Data.Ordering∷Ordering.LT" == (M.Data_Ord_foreign.ordIntImpl({
                ["$ctor"] = "Data.Ordering∷Ordering.LT"
              })({ ["$ctor"] = "Data.Ordering∷Ordering.EQ" })({
                ["$ctor"] = "Data.Ordering∷Ordering.GT"
              })(i_S_2)(n))["$ctor"] then
                return false
              else
                return true
              end
            end)() then
              return pure((function(value0)
                return {
                  ["$ctor"] = "Control.Monad.Rec.Class∷Step.Done",
                  value0 = value0
                }
              end)(acc_S_1))
            else
              return pure((function(value0)
                return {
                  ["$ctor"] = "Control.Monad.Rec.Class∷Step.Loop",
                  value0 = value0
                }
              end)({
                a = M.Data_Semiring_foreign.intAdd(acc_S_1)(i_S_2),
                b = M.Data_Semiring_foreign.intAdd(i_S_2)(1)
              }))
            end
          end
        end)()(o_S_450.b)
      end)({ a = b, b = 0 })
    end
  end
end
return (function()
  local r_S_0 = M.Golden_TailRecM2Shadow_Test_sumFrom({
    tailRecM = function(f_S_11)
      return function(a_S_12)
        return function()
          local Effect_Ref_foreign = M.Effect_Ref_foreign
          local r_S_16 = M.Control_Bind_bind(M.Effect_bindEffect)(f_S_11(a_S_12))(Effect_Ref_foreign._new)()
          local _ = M.Effect_foreign.untilE(function()
            local v0_S_17 = M.Effect_Ref_foreign.read(r_S_16)()
            return (function()
              if "Control.Monad.Rec.Class∷Step.Loop" == v0_S_17["$ctor"] then
                return function()
                  local e_S_19 = f_S_11(v0_S_17.value0)()
                  local _ = M.Effect_Ref_foreign.write(e_S_19)(r_S_16)()
                  return M.Control_Monad_Rec_Class_pure(false)()
                end
              elseif "Control.Monad.Rec.Class∷Step.Done" == v0_S_17["$ctor"] then
                return M.Control_Monad_Rec_Class_pure(true)
              else
                return error("No patterns matched")
              end
            end)()()
          end)()
          return M.Effect_functorEffect.map(M.Partial_Unsafe_foreign._unsafePartial(function(  )
            return function(v_S_9_S_20)
              if "Control.Monad.Rec.Class∷Step.Done" == v_S_9_S_20["$ctor"] then
                return v_S_9_S_20.value0
              else
                return error("No patterns matched")
              end
            end
          end))(Effect_Ref_foreign.read(r_S_16))()
        end
      end
    end,
    Monad0 = function() return M.Effect_monadEffect end
  })(0)(5)()
  return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(r_S_0))()
end)()
