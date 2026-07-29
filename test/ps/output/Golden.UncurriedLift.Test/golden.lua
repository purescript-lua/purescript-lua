local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Control_Monad_ST_Internal_foreign = {
  pure_ = function(a) return function() return a end end,
  run = function(f) return f() end
}
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_UncurriedLift_Test_logShow = function(a_S_0)
  return Effect_Console_log(Data_Show_foreign.showIntImpl(a_S_0))
end
local Golden_UncurriedLift_Test_sumST = function(a_S_1, b_S_0)
  return a_S_1 + b_S_0
end
local Golden_UncurriedLift_Test_mulByFn = function(a_S_2, b_S_1)
  return a_S_2 * b_S_1
end
local Golden_UncurriedLift_Test_mul2 = function(a_S_3, b_S_2)
  return a_S_3 * b_S_2
end
local Golden_UncurriedLift_Test_logTwice = function(a_S_4, b_S_3)
  local _ = Effect_Console_log(a_S_4)()
  return Effect_Console_log(b_S_3)()
end
local Golden_UncurriedLift_Test_add3 = function(a_S_5, b_S_4, c_S_0)
  return a_S_5 + b_S_4 + c_S_0
end
local Golden_UncurriedLift_Test_addOnePlusTwoTo = function(c_S_1)
  return 3 + c_S_1
end
return (function()
  local _ = Golden_UncurriedLift_Test_logTwice("hello", "world")
  local _ = Golden_UncurriedLift_Test_logShow(Golden_UncurriedLift_Test_add3(1, 2, 3))()
  local _ = Golden_UncurriedLift_Test_logShow(Golden_UncurriedLift_Test_mul2(4, 5))()
  local _ = Golden_UncurriedLift_Test_logShow(Golden_UncurriedLift_Test_mulByFn(6, 8))()
  local _ = Golden_UncurriedLift_Test_logShow(Golden_UncurriedLift_Test_addOnePlusTwoTo(100))()
  local _ = Golden_UncurriedLift_Test_logShow(Golden_UncurriedLift_Test_addOnePlusTwoTo(200))()
  return Golden_UncurriedLift_Test_logShow(Control_Monad_ST_Internal_foreign.run(function(  )
    return Golden_UncurriedLift_Test_sumST(40, 2)
  end))()
end)()
