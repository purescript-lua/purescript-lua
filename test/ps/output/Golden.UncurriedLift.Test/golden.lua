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
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Control_Monad_ST_Internal_foreign = {
  map_ = function(f)
    return function(a) return function() return f(a()) end end
  end,
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
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
      local bind_S_759 = (Control_Monad_ST_Internal_monadST.Bind1()).bind
      return function(f_S_760)
        return function(a_S_761)
          return bind_S_759(f_S_760)(function(fPrime_S_762)
            return bind_S_759(a_S_761)(function(aPrime_S_763)
              return (Control_Monad_ST_Internal_monadST.Applicative0()).pure(fPrime_S_762(aPrime_S_763))
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
local Golden_UncurriedLift_Test_sumST = function(a_S_705, b_S_706)
  return Control_Monad_ST_Internal_applicativeST.pure(a_S_705 + b_S_706)()
end
local Golden_UncurriedLift_Test_mulByFn = function(a_S_696, b_S_697)
  return a_S_696 * b_S_697
end
local Golden_UncurriedLift_Test_mul2 = function(a_S_699, b_S_700)
  return a_S_699 * b_S_700
end
local Golden_UncurriedLift_Test_logTwice = function(a_S_671, b_S_672)
  return (function()
    local _ = Effect_Console_log(a_S_671)()
    return Effect_Console_log(b_S_672)()
  end)()
end
local Golden_UncurriedLift_Test_add3 = function(a_S_692, b_S_693, c_S_694)
  return a_S_692 + b_S_693 + c_S_694
end
M.Golden_UncurriedLift_Test_addOnePlusTwoTo = function(c_S_680)
  return Golden_UncurriedLift_Test_add3(1, 2, c_S_680)
end
return (function()
  local _ = Golden_UncurriedLift_Test_logTwice("hello", "world")
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 3)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_UncurriedLift_Test_mul2(4, 5)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_UncurriedLift_Test_mulByFn(6, 8)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 100)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 200)))()
  return Effect_Console_log(Data_Show_showIntImpl(Control_Monad_ST_Internal_foreign.run(function(  )
    return Golden_UncurriedLift_Test_sumST(40, 2)
  end)))()
end)()
