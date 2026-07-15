local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_Tuple_append_S_w = function(s1_S_386, s2_S_387)
  return s1_S_386 .. s2_S_387
end
local Data_Tuple_Tuple_S_w = function(value0, value1)
  return { value0, value1 }
end
M.Golden_CprResult_Test_step = function(s)
  return Data_Tuple_Tuple_S_w(s * 2, s + 1)
end
M.Golden_CprResult_Test_useStep = function(n) return n * 2 + (n + 1) end
local Golden_CprResult_Test_pair = Data_Tuple_Tuple_S_w(20, 11)
local Golden_CprResult_Test_branchy = function(n)
  if not(n < 0) and n ~= 0 then
    local b1 = n + 7
    local b2 = b1 + n
    local b3 = b2 - 4
    local b4 = b3 + b1
    local b5 = b4 + b2
    local b6 = b5 - b3
    local b7 = b6 + b4
    return Data_Tuple_Tuple_S_w(b1 + b3 + b5 + b7, b2 + b4 + b6 + (b7 - b5))
  else
    local c1 = 3 - n
    local c2 = c1 + 5
    local c3 = c2 - n
    local c4 = c3 + c1
    local c5 = c4 + c2
    local c6 = c5 - c3
    local c7 = c6 + c4
    return Data_Tuple_Tuple_S_w(c1 + c3 + c5 + c7, c2 + c4 + c6 + (c7 - c5))
  end
end
local Golden_CprResult_Test_keepBranchy = Golden_CprResult_Test_branchy(3)
M.Golden_CprResult_Test_useBranchy = function(n)
  local v = Golden_CprResult_Test_branchy(n)
  return v[1] - v[2]
end
local Golden_CprResult_Test_big = function(n)
  local a1 = n + 1
  local a2 = a1 + 3
  local a3 = a2 - n
  local a4 = a3 + a1
  local a5 = a4 + 2
  local a6 = a5 + a2
  local a7 = a6 - a3
  local a8 = a7 + a4
  local a9 = a8 + 1
  local a10 = a9 - a5
  local a11 = a10 + a6
  local a12 = a11 - a7
  local a13 = a12 + a8
  local a14 = a13 + a9
  local a15 = a14 - a10
  return Data_Tuple_Tuple_S_w(a1 + a3 + a5 + a7 + a9 + a11 + a13 + a15, a2 + a4 + a6 + a8 + a10 + a12 + a14 + (a15 + a11))
end
M.Golden_CprResult_Test_useBig = function(n)
  local v = Golden_CprResult_Test_big(n)
  return v[1] + v[2]
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(16))()
  local _ = Effect_Console_log(Data_Tuple_append_S_w("(Tuple ", Data_Tuple_append_S_w(Data_Show_showIntImpl(Golden_CprResult_Test_pair[1]), Data_Tuple_append_S_w(" ", Data_Tuple_append_S_w(Data_Show_showIntImpl(Golden_CprResult_Test_pair[2]), ")")))))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local v_S_531 = Golden_CprResult_Test_branchy(7)
    return v_S_531[1] - v_S_531[2]
  end)()))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local v_S_536 = Golden_CprResult_Test_branchy(-7)
    return v_S_536[1] - v_S_536[2]
  end)()))()
  local _ = Effect_Console_log(Data_Tuple_append_S_w("(Tuple ", Data_Tuple_append_S_w(Data_Show_showIntImpl(Golden_CprResult_Test_keepBranchy[1]), Data_Tuple_append_S_w(" ", Data_Tuple_append_S_w(Data_Show_showIntImpl(Golden_CprResult_Test_keepBranchy[2]), ")")))))()
  return Effect_Console_log(Data_Show_showIntImpl((function()
    local v_S_538 = Golden_CprResult_Test_big(3)
    return v_S_538[1] + v_S_538[2]
  end)()))()
end)()
