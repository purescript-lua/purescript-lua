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
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_239))(a_S_240)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_219 = (M.Effect_monadEffect.Bind1()).bind
      return function(f_S_221)
        return function(a_S_222)
          return bind_S_219(f_S_221)(function(fPrime_S_223)
            return bind_S_219(a_S_222)(function(aPrime_S_224)
              return (M.Effect_monadEffect.Applicative0()).pure(fPrime_S_223(aPrime_S_224))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Effect_functorEffect = M.Effect_Lazy_functorEffect(0)
M.Control_Monad_Rec_Class_pure = M.Effect_applicativeEffect.pure
M.Golden_TailRecM2Shadow_Test_add_S_w = function(x_S_457_S_491, y_S_458_S_492)
  return x_S_457_S_491 + y_S_458_S_492
end
M.Golden_TailRecM2Shadow_Test_sumFrom = function(dictMonadRec)
  local pure = ((dictMonadRec.Monad0()).Applicative0()).pure
  return function(b)
    return function(n)
      return dictMonadRec.tailRecM(function(o_S_483)
        return (function()
          local acc_S_1 = o_S_483.a
          return function(i_S_2)
            if "Data.Ordering∷Ordering.LT" == (function()
              if i_S_2 < n then
                return "Data.Ordering∷Ordering.LT"
              elseif i_S_2 == n then
                return "Data.Ordering∷Ordering.EQ"
              else
                return "Data.Ordering∷Ordering.GT"
              end
            end)() then
              return pure((function(value0)
                return {
                  ["$ctor"] = "Control.Monad.Rec.Class∷Step.Loop",
                  value0 = value0
                }
              end)({
                a = M.Golden_TailRecM2Shadow_Test_add_S_w(acc_S_1, i_S_2),
                b = M.Golden_TailRecM2Shadow_Test_add_S_w(i_S_2, 1)
              }))
            else
              return pure((function(value0)
                return {
                  ["$ctor"] = "Control.Monad.Rec.Class∷Step.Done",
                  value0 = value0
                }
              end)(acc_S_1))
            end
          end
        end)()(o_S_483.b)
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
            local Effect_Ref_foreign = M.Effect_Ref_foreign
            local r_S_16 = M.Effect_bindEffect.bind(f_S_11(a_S_12))(Effect_Ref_foreign._new)()
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
    }
    local pure_S_536 = ((dictMonadRec_S_535.Monad0()).Applicative0()).pure
    return function(b_S_537)
      return function(n_S_538)
        return dictMonadRec_S_535.tailRecM(function(o_S_483_S_539)
          return (function()
            local acc_S_1_S_540 = o_S_483_S_539.a
            return function(i_S_2_S_541)
              if "Data.Ordering∷Ordering.LT" == (function()
                if i_S_2_S_541 < n_S_538 then
                  return "Data.Ordering∷Ordering.LT"
                elseif i_S_2_S_541 == n_S_538 then
                  return "Data.Ordering∷Ordering.EQ"
                else
                  return "Data.Ordering∷Ordering.GT"
                end
              end)() then
                return pure_S_536((function(value0)
                  return {
                    ["$ctor"] = "Control.Monad.Rec.Class∷Step.Loop",
                    value0 = value0
                  }
                end)({
                  a = M.Golden_TailRecM2Shadow_Test_add_S_w(acc_S_1_S_540, i_S_2_S_541),
                  b = M.Golden_TailRecM2Shadow_Test_add_S_w(i_S_2_S_541, 1)
                }))
              else
                return pure_S_536((function(value0)
                  return {
                    ["$ctor"] = "Control.Monad.Rec.Class∷Step.Done",
                    value0 = value0
                  }
                end)(acc_S_1_S_540))
              end
            end
          end)()(o_S_483_S_539.b)
        end)({ a = b_S_537, b = 0 })
      end
    end
  end)()(0)(5)()
  return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl((function(  )
    local dictMonadRec_S_535_S_543 = {
      tailRecM = function(f_S_11_S_544)
        return function(a_S_12_S_545)
          return function()
            local Effect_Ref_foreign = M.Effect_Ref_foreign
            local r_S_16_S_546 = M.Effect_bindEffect.bind(f_S_11_S_544(a_S_12_S_545))(Effect_Ref_foreign._new)()
            local __S_547 = M.Effect_foreign.untilE(function()
              local v0_S_17_S_548 = M.Effect_Ref_foreign.read(r_S_16_S_546)()
              return (function()
                if "Control.Monad.Rec.Class∷Step.Loop" == v0_S_17_S_548["$ctor"] then
                  return function()
                    local e_S_19_S_549 = f_S_11_S_544(v0_S_17_S_548.value0)()
                    local __S_550 = M.Effect_Ref_foreign.write(e_S_19_S_549)(r_S_16_S_546)()
                    return M.Control_Monad_Rec_Class_pure(false)()
                  end
                elseif "Control.Monad.Rec.Class∷Step.Done" == v0_S_17_S_548["$ctor"] then
                  return M.Control_Monad_Rec_Class_pure(true)
                else
                  return error("No patterns matched")
                end
              end)()()
            end)()
            return M.Effect_functorEffect.map(M.Partial_Unsafe_foreign._unsafePartial(function(  )
              return function(v_S_9_S_20_S_551)
                if "Control.Monad.Rec.Class∷Step.Done" == v_S_9_S_20_S_551["$ctor"] then
                  return v_S_9_S_20_S_551.value0
                else
                  return error("No patterns matched")
                end
              end
            end))(Effect_Ref_foreign.read(r_S_16_S_546))()
          end
        end
      end,
      Monad0 = function() return M.Effect_monadEffect end
    }
    local pure_S_536_S_552 = ((dictMonadRec_S_535_S_543.Monad0()).Applicative0()).pure
    return function(b_S_537_S_553)
      return function(n_S_538_S_554)
        return dictMonadRec_S_535_S_543.tailRecM(function(o_S_483_S_539_S_555)
          return (function()
            local acc_S_1_S_540_S_556 = o_S_483_S_539_S_555.a
            return function(i_S_2_S_541_S_557)
              if "Data.Ordering∷Ordering.LT" == (function()
                if i_S_2_S_541_S_557 < n_S_538_S_554 then
                  return "Data.Ordering∷Ordering.LT"
                elseif i_S_2_S_541_S_557 == n_S_538_S_554 then
                  return "Data.Ordering∷Ordering.EQ"
                else
                  return "Data.Ordering∷Ordering.GT"
                end
              end)() then
                return pure_S_536_S_552((function(value0)
                  return {
                    ["$ctor"] = "Control.Monad.Rec.Class∷Step.Loop",
                    value0 = value0
                  }
                end)({
                  a = M.Golden_TailRecM2Shadow_Test_add_S_w(acc_S_1_S_540_S_556, i_S_2_S_541_S_557),
                  b = M.Golden_TailRecM2Shadow_Test_add_S_w(i_S_2_S_541_S_557, 1)
                }))
              else
                return pure_S_536_S_552((function(value0)
                  return {
                    ["$ctor"] = "Control.Monad.Rec.Class∷Step.Done",
                    value0 = value0
                  }
                end)(acc_S_1_S_540_S_556))
              end
            end
          end)()(o_S_483_S_539_S_555.b)
        end)({ a = b_S_537_S_553, b = 0 })
      end
    end
  end)()(0)(5)()))()
end)()
