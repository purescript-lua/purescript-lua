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
M.Control_Monad_ST_Internal_foreign = {
  map_ = function(f)
    return function(a) return function() return f(a()) end end
  end,
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Control_Monad_ST_Internal_monadST = {
  Applicative0 = function()
    return M.Control_Monad_ST_Internal_applicativeST
  end,
  Bind1 = function() return M.Control_Monad_ST_Internal_bindST end
}
M.Control_Monad_ST_Internal_bindST = {
  bind = M.Control_Monad_ST_Internal_foreign.bind_,
  Apply0 = function() return M.Control_Monad_ST_Internal_Lazy_applyST(0) end
}
M.Control_Monad_ST_Internal_applicativeST = {
  pure = M.Control_Monad_ST_Internal_foreign.pure_,
  Apply0 = function() return M.Control_Monad_ST_Internal_Lazy_applyST(0) end
}
M.Control_Monad_ST_Internal_Lazy_applyST = PSLUA_runtime_lazy("applyST")(function(  )
  return {
    apply = (function()
      local bind_S_759 = (M.Control_Monad_ST_Internal_monadST.Bind1()).bind
      return function(f_S_760)
        return function(a_S_761)
          return bind_S_759(f_S_760)(function(fPrime_S_762)
            return bind_S_759(a_S_761)(function(aPrime_S_763)
              return (M.Control_Monad_ST_Internal_monadST.Applicative0()).pure(fPrime_S_762(aPrime_S_763))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return { map = M.Control_Monad_ST_Internal_foreign.map_ }
    end
  }
end)
M.Golden_UncurriedLift_Test_sumST = function(a_S_705, b_S_706)
  return M.Control_Monad_ST_Internal_applicativeST.pure(a_S_705 + b_S_706)()
end
M.Golden_UncurriedLift_Test_mulByFn = function(a_S_696, b_S_697)
  return a_S_696 * b_S_697
end
M.Golden_UncurriedLift_Test_mul2 = function(a_S_699, b_S_700)
  return a_S_699 * b_S_700
end
M.Golden_UncurriedLift_Test_logTwice = function(a_S_671, b_S_672)
  local Effect_Console_foreign = M.Effect_Console_foreign
  return (function()
    local _ = Effect_Console_foreign.log(a_S_671)()
    return Effect_Console_foreign.log(b_S_672)()
  end)()
end
M.Golden_UncurriedLift_Test_add3 = function(a_S_692, b_S_693, c_S_694)
  return a_S_692 + b_S_693 + c_S_694
end
M.Golden_UncurriedLift_Test_addOnePlusTwoTo = function(c_S_680)
  return M.Golden_UncurriedLift_Test_add3(1, 2, c_S_680)
end
return (function()
  local Data_Show_foreign, Effect_Console_foreign, Golden_UncurriedLift_Test_add3 = M.Data_Show_foreign, M.Effect_Console_foreign, M.Golden_UncurriedLift_Test_add3
  local _ = M.Golden_UncurriedLift_Test_logTwice("hello", "world")
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(M.Golden_UncurriedLift_Test_mul2(4, 5)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(M.Golden_UncurriedLift_Test_mulByFn(6, 8)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 100)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 200)))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(M.Control_Monad_ST_Internal_foreign.run(function(  )
    return M.Golden_UncurriedLift_Test_sumST(40, 2)
  end)))()
end)()
