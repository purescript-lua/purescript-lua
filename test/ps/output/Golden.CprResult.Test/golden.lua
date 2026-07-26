local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_Tuple_Tuple_S_w = function(value0, value1)
  return { value0, value1 }
end
local Golden_CprResult_Test_sub_S_w = function(x_S_525, y_S_526)
  return x_S_525 - y_S_526
end
local Golden_CprResult_Test_logShow = function(a_S_522)
  return Effect_Console_log(Data_Show_showIntImpl(a_S_522))
end
local Golden_CprResult_Test_logShow1 = function(a_S_519)
  return Effect_Console_log("(Tuple " .. Data_Show_showIntImpl(a_S_519[1]) .. " " .. Data_Show_showIntImpl(a_S_519[2]) .. ")")
end
M.Golden_CprResult_Test_step = function(s)
  return Data_Tuple_Tuple_S_w(s * 2, s + 1)
end
M.Golden_CprResult_Test_useStep = function(n) return n * 2 + (n + 1) end
local Golden_CprResult_Test_pair = Data_Tuple_Tuple_S_w(20, 11)
local Golden_CprResult_Test_branchy_S_r = function(n)
  if not(n < 0) and n ~= 0 then
    local b1 = n + 7
    local b2 = b1 + n
    local b3 = b2 - 4
    local b4 = b3 + b1
    local b5 = b4 + b2
    local b6 = b5 - b3
    local b7 = b6 + b4
    return b1 + b3 + b5 + b7, b2 + b4 + b6 + (b7 - b5)
  else
    local c1 = 3 - n
    local c2 = c1 + 5
    local c3 = c2 - n
    local c4 = c3 + c1
    local c5 = c4 + c2
    local c6 = c5 - c3
    local c7 = c6 + c4
    return c1 + c3 + c5 + c7, c2 + c4 + c6 + (c7 - c5)
  end
end
local Golden_CprResult_Test_branchy = function(branchy_S_p1)
  local branchy_S_v1, branchy_S_v2 = Golden_CprResult_Test_branchy_S_r(branchy_S_p1)
  return { branchy_S_v1, branchy_S_v2 }
end
local Golden_CprResult_Test_keepBranchy = Golden_CprResult_Test_branchy(3)
M.Golden_CprResult_Test_useBranchy = function(n)
  local _S_v596, _S_v597 = Golden_CprResult_Test_branchy_S_r(n)
  return _S_v596 - _S_v597
end
local Golden_CprResult_Test_big_S_r = function(n)
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
  return a1 + a3 + a5 + a7 + a9 + a11 + a13 + a15, a2 + a4 + a6 + a8 + a10 + a12 + a14 + (a15 + a11)
end
M.Golden_CprResult_Test_big = function(big_S_p1)
  local big_S_v1, big_S_v2 = Golden_CprResult_Test_big_S_r(big_S_p1)
  return { big_S_v1, big_S_v2 }
end
M.Golden_CprResult_Test_useBig = function(n)
  local _S_v598, _S_v599 = Golden_CprResult_Test_big_S_r(n)
  return _S_v598 + _S_v599
end
return (function()
  local _ = Golden_CprResult_Test_logShow(16)()
  local _ = Golden_CprResult_Test_logShow1(Golden_CprResult_Test_pair)()
  local _ = Golden_CprResult_Test_logShow((function()
    local _S_v600, _S_v601 = Golden_CprResult_Test_branchy_S_r(7)
    return Golden_CprResult_Test_sub_S_w(_S_v600, _S_v601)
  end)())()
  local _ = Golden_CprResult_Test_logShow((function()
    local _S_v602, _S_v603 = Golden_CprResult_Test_branchy_S_r(-7)
    return Golden_CprResult_Test_sub_S_w(_S_v602, _S_v603)
  end)())()
  local _ = Golden_CprResult_Test_logShow1(Golden_CprResult_Test_keepBranchy)()
  return Golden_CprResult_Test_logShow((function()
    local _S_v604, _S_v605 = Golden_CprResult_Test_big_S_r(3)
    return _S_v604 + _S_v605
  end)())()
end)()
