local M = {}
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
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
M.Golden_UncurriedLift_Test_addOnePlusTwoTo = function(c_S_314)
  return M.Golden_UncurriedLift_Test_add3(1, 2, c_S_314)
end
return (function()
  local Data_Show_foreign, Effect_Console_foreign, Golden_UncurriedLift_Test_add3 = M.Data_Show_foreign, M.Effect_Console_foreign, M.Golden_UncurriedLift_Test_add3
  local _ = M.Golden_UncurriedLift_Test_logTwice("hello", "world")
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 3)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(M.Golden_UncurriedLift_Test_mul2(4, 5)))()
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 100)))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_UncurriedLift_Test_add3(1, 2, 200)))()
end)()
