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
  return { eqCharImpl = refEq }
end)()
M.Data_Show_foreign = {
  showCharImpl = function(n)
    local code = n:byte()
    if code < 32 or code == 127 then
      if n == "\a" then return "'\\a'" end
      if n == "\b" then return "'\\b'" end
      if n == "\f" then return "'\\f'" end
      if n == "\n" then return "'\\n'" end
      if n == "\r" then return "'\\r'" end
      if n == "\t" then return "'\\t'" end
      if n == "\v" then return "'\\v'" end
      return "'\\" .. tostring(code) .. "'"
    end
    if n == "'" or n == "\\" then return "'\\" .. n .. "'" end
    return "'" .. n .. "'"
  end
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
  return { ordCharImpl = unsafeCoerceImpl }
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
M.Data_Show_show = function(dict) return dict.show end
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
    map = function(f_S_25)
      return function(a_S_26)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_25))(a_S_26)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_4 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_6)
        return function(a_S_7)
          return bind_S_4(f_S_6)(function(fPrime_S_8)
            return bind_S_4(a_S_7)(function(aPrime_S_9)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_8(aPrime_S_9))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Golden_CharLiterals_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_CharLiterals_Test_show = M.Data_Show_show({
  show = M.Data_Show_foreign.showCharImpl
})
M.Golden_CharLiterals_Test_show1 = M.Data_Show_show({
  show = function(v_S_111)
    if v_S_111 then
      return "true"
    elseif false == v_S_111 then
      return "false"
    else
      return error("No patterns matched")
    end
  end
})
return (function()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show("\n"))()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show("\t"))()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show("\r"))()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show("\'"))()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show("\\"))()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show("a"))()
  local _ = M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show1(M.Data_Eq_foreign.eqCharImpl("\n")("\n")))()
  return M.Effect_Console_foreign.log(M.Golden_CharLiterals_Test_show1((function(  )
    if "Data.Ordering∷Ordering.LT" == (M.Data_Ord_foreign.ordCharImpl({
      ["$ctor"] = "Data.Ordering∷Ordering.LT"
    })({ ["$ctor"] = "Data.Ordering∷Ordering.EQ" })({
      ["$ctor"] = "Data.Ordering∷Ordering.GT"
    })("\t")("\n"))["$ctor"] then
      return true
    else
      return false
    end
  end)()))()
end)()
