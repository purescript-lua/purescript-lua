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
M.Data_Eq_foreign = (function()
  local refEq = function(r1) return function(r2) return r1 == r2 end end
  return { eqIntImpl = refEq }
end)()
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end,
  intMul = function(x) return function(y) return x * y end end
}
M.Data_Ring_foreign = {
  intSub = function(x) return function(y) return x - y end end
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
  end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Data_Eq_eqInt = { eq = M.Data_Eq_foreign.eqIntImpl }
M.Data_Semiring_semiringInt = {
  add = M.Data_Semiring_foreign.intAdd,
  zero = 0,
  mul = M.Data_Semiring_foreign.intMul,
  one = 1
}
M.Data_Ord_ordInt = {
  compare = M.Data_Ord_foreign.ordIntImpl({
    ["$ctor"] = "Data.Ordering∷Ordering.LT"
  })({ ["$ctor"] = "Data.Ordering∷Ordering.EQ" })({
    ["$ctor"] = "Data.Ordering∷Ordering.GT"
  }),
  Eq0 = function() return M.Data_Eq_eqInt end
}
M.Data_Ord_compare = function(dict) return dict.compare end
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
    map = function(f_S_28)
      return function(a_S_29)
        local Effect_applicativeEffect = M.Effect_applicativeEffect
        return (Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(Effect_applicativeEffect)(f_S_28))(a_S_29)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_7 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_9)
        return function(a_S_10)
          return bind_S_7(f_S_9)(function(fPrime_S_11)
            return bind_S_7(a_S_10)(function(aPrime_S_12)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_11(aPrime_S_12))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_Loopification_Test_eq = M.Data_Eq_eqInt.eq
M.Golden_Loopification_Test_add = M.Data_Semiring_semiringInt.add
M.Golden_Loopification_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_Loopification_Test_logShow = function(a_S_2)
  return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(a_S_2))
end
M.Golden_Loopification_Test_sumTo_S_w = function(acc, n)
  local Data_Ring_foreign, Golden_Loopification_Test_add, Golden_Loopification_Test_eq = M.Data_Ring_foreign, M.Golden_Loopification_Test_add, M.Golden_Loopification_Test_eq
  while true do
    if Golden_Loopification_Test_eq(n)(0) then
      return acc
    else
      acc, n = Golden_Loopification_Test_add(acc)(n), Data_Ring_foreign.intSub(n)(1)
    end
  end
end
M.Golden_Loopification_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return M.Golden_Loopification_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
M.Golden_Loopification_Test_sumSquares = function(m)
  local go_S_w
  go_S_w = function(acc, n)
    local Data_Ring_foreign, Data_Semiring_semiringInt, Golden_Loopification_Test_add, Golden_Loopification_Test_eq = M.Data_Ring_foreign, M.Data_Semiring_semiringInt, M.Golden_Loopification_Test_add, M.Golden_Loopification_Test_eq
    while true do
      if Golden_Loopification_Test_eq(n)(0) then
        return acc
      else
        acc, n = Golden_Loopification_Test_add(acc)(Data_Semiring_semiringInt.mul(n)(n)), Data_Ring_foreign.intSub(n)(1)
      end
    end
  end
  return go_S_w(0, m)
end
M.Golden_Loopification_Test_sumCPS_S_w = function(n, k)
  if M.Golden_Loopification_Test_eq(n)(0) then
    return k(0)
  else
    return M.Golden_Loopification_Test_sumCPS_S_w(M.Data_Ring_foreign.intSub(n)(1), function( r )
      return k(M.Golden_Loopification_Test_add(r)(n))
    end)
  end
end
M.Golden_Loopification_Test_sumCPS = function(sumCPS_S_p1)
  return function(sumCPS_S_p2)
    return M.Golden_Loopification_Test_sumCPS_S_w(sumCPS_S_p1, sumCPS_S_p2)
  end
end
M.Golden_Loopification_Test_mc91 = function(n)
  local Data_Ord_compare, Data_Ord_ordInt, Data_Ring_foreign, Golden_Loopification_Test_add, Golden_Loopification_Test_mc91 = M.Data_Ord_compare, M.Data_Ord_ordInt, M.Data_Ring_foreign, M.Golden_Loopification_Test_add, M.Golden_Loopification_Test_mc91
  while true do
    if (function()
      if "Data.Ordering∷Ordering.GT" == (Data_Ord_compare(Data_Ord_ordInt)(n)(100))["$ctor"] then
        return true
      else
        return false
      end
    end)() then
      return Data_Ring_foreign.intSub(n)(10)
    else
      n = Golden_Loopification_Test_mc91(Golden_Loopification_Test_add(n)(11))
    end
  end
end
M.Golden_Loopification_Test_countdown = function(n)
  local Data_Ord_compare, Data_Ord_ordInt, Data_Ring_foreign = M.Data_Ord_compare, M.Data_Ord_ordInt, M.Data_Ring_foreign
  while true do
    if (function()
      if "Data.Ordering∷Ordering.GT" == (Data_Ord_compare(Data_Ord_ordInt)(n)(0))["$ctor"] then
        return false
      else
        return true
      end
    end)() then
      return 0
    else
      n = Data_Ring_foreign.intSub(n)(1)
    end
  end
end
M.Golden_Loopification_Test_countDrop_S_w = function(n)
  local Data_Ring_foreign, Golden_Loopification_Test_eq = M.Data_Ring_foreign, M.Golden_Loopification_Test_eq
  while true do
    if Golden_Loopification_Test_eq(n)(0) then
      return 0
    else
      n = Data_Ring_foreign.intSub(n)(1)
    end
  end
end
M.Golden_Loopification_Test_countDrop = function(countDrop_S_p1)
  return function(countDrop_S_p2)
    return M.Golden_Loopification_Test_countDrop_S_w(countDrop_S_p1, countDrop_S_p2)
  end
end
return (function()
  local Golden_Loopification_Test_logShow = M.Golden_Loopification_Test_logShow
  local _ = Golden_Loopification_Test_logShow(M.Golden_Loopification_Test_countdown(5))()
  local _ = Golden_Loopification_Test_logShow(M.Golden_Loopification_Test_sumTo_S_w(0, 10))()
  local _ = Golden_Loopification_Test_logShow(M.Golden_Loopification_Test_sumSquares(4))()
  local _ = Golden_Loopification_Test_logShow(M.Golden_Loopification_Test_mc91(1))()
  local _ = Golden_Loopification_Test_logShow(M.Golden_Loopification_Test_sumCPS_S_w(5, function( x_S_193 )
    return x_S_193
  end))()
  return Golden_Loopification_Test_logShow(M.Golden_Loopification_Test_countDrop_S_w(3, 99))()
end)()
