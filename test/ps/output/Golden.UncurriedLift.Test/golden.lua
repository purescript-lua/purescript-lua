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
M.Control_Monad_ST_Uncurried_foreign = {
  mkSTFn2 = function(fn) return function(a, b) return fn(a)(b)() end end
}
M.Data_Function_Uncurried_foreign = {
  mkFn2 = function(fn) return function(a, b) return fn(a)(b) end end,
  mkFn3 = function(fn) return function(a, b, c) return fn(a)(b)(c) end end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Effect_Uncurried_foreign = {
  mkEffectFn2 = function(fn) return function(a, b) return fn(a)(b)() end end
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
      local bind_S_604 = (M.Control_Monad_ST_Internal_monadST.Bind1()).bind
      return function(f_S_605)
        return function(a_S_606)
          return bind_S_604(f_S_605)(function(fPrime_S_607)
            return bind_S_604(a_S_606)(function(aPrime_S_608)
              return (M.Control_Monad_ST_Internal_monadST.Applicative0()).pure(fPrime_S_607(aPrime_S_608))
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
M.Golden_UncurriedLift_Test_sumST = M.Control_Monad_ST_Uncurried_foreign.mkSTFn2(function( a )
  return function(b)
    return M.Control_Monad_ST_Internal_applicativeST.pure(a + b)
  end
end)
M.Golden_UncurriedLift_Test_mul2 = M.Data_Function_Uncurried_foreign.mkFn2(function( a )
  return function(b) return a * b end
end)
M.Golden_UncurriedLift_Test_logTwice = M.Effect_Uncurried_foreign.mkEffectFn2(function( a )
  return function(b)
    return function()
      local Effect_Console_foreign = M.Effect_Console_foreign
      local _ = Effect_Console_foreign.log(a)()
      return Effect_Console_foreign.log(b)()
    end
  end
end)
M.Golden_UncurriedLift_Test_add3 = M.Data_Function_Uncurried_foreign.mkFn3(function( a )
  return function(b) return function(c) return a + b + c end end
end)
M.Golden_UncurriedLift_Test_addOnePlusTwoTo = function(c_S_547)
  return M.Golden_UncurriedLift_Test_add3(1, 2, c_S_547)
end
return (function()
  local Data_Show_foreign, Effect_Console_foreign, Golden_UncurriedLift_Test_add3 = M.Data_Show_foreign, M.Effect_Console_foreign, M.Golden_UncurriedLift_Test_add3
  local _ = M.Golden_UncurriedLift_Test_logTwice("hello", "world")
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(M.Golden_UncurriedLift_Test_mul2(4, 5)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 100)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 200)))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(M.Control_Monad_ST_Internal_foreign.run(function(  )
    return M.Golden_UncurriedLift_Test_sumST(40, 2)
  end)))()
end)()
