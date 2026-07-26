local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Control_Monad_ST_Internal_foreign = {
  pure_ = function(a) return function() return a end end,
  run = function(f) return f() end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_UncurriedLift_Test_sumST = function(a_S_0, b_S_0)
  return a_S_0 + b_S_0
end
M.Golden_UncurriedLift_Test_mulByFn = function(a_S_1, b_S_1)
  return a_S_1 * b_S_1
end
M.Golden_UncurriedLift_Test_mul2 = function(a_S_2, b_S_2)
  return a_S_2 * b_S_2
end
local Golden_UncurriedLift_Test_logTwice = function(a_S_3, b_S_3)
  local _ = Effect_Console_log(a_S_3)()
  return Effect_Console_log(b_S_3)()
end
M.Golden_UncurriedLift_Test_add3 = function(a_S_4, b_S_4, c_S_0)
  return a_S_4 + b_S_4 + c_S_0
end
M.Golden_UncurriedLift_Test_addOnePlusTwoTo = function(c_S_1)
  return 3 + c_S_1
end
return (function()
  local _ = Golden_UncurriedLift_Test_logTwice("hello", "world")
  local _ = Effect_Console_log(Data_Show_showIntImpl(6))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(20))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(48))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(103))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(203))()
  return Effect_Console_log(Data_Show_showIntImpl(Control_Monad_ST_Internal_foreign.run(function(  )
    return 42
  end)))()
end)()
