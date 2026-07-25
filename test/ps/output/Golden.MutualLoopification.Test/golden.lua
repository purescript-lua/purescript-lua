local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_MutualLoopification_Test_logShow = function(a_S_294)
  return Effect_Console_log((function()
    if a_S_294 then return "true" else return "false" end
  end)())
end
local Golden_MutualLoopification_Test_logShow1 = function(a_S_292)
  return Effect_Console_log(Data_Show_foreign.showIntImpl(a_S_292))
end
local Golden_MutualLoopification_Test_zag_S_w
local Golden_MutualLoopification_Test_zigzag_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_MutualLoopification_Test_zag_S_w(acc, n, 1)
  end
end
M.Golden_MutualLoopification_Test_zigzag = function(zigzag_S_p1)
  return function(zigzag_S_p2)
    return Golden_MutualLoopification_Test_zigzag_S_w(zigzag_S_p1, zigzag_S_p2)
  end
end
Golden_MutualLoopification_Test_zag_S_w = function(acc, n, d)
  if n == 0 then
    return acc
  else
    return Golden_MutualLoopification_Test_zigzag_S_w(acc + d, n - 1)
  end
end
M.Golden_MutualLoopification_Test_zag = function(zag_S_p1)
  return function(zag_S_p2)
    return function(zag_S_p3)
      return Golden_MutualLoopification_Test_zag_S_w(zag_S_p1, zag_S_p2, zag_S_p3)
    end
  end
end
local Golden_MutualLoopification_Test_treeA
local Golden_MutualLoopification_Test_treeB = function(n)
  if n == 0 then
    return 2
  else
    return 2 + Golden_MutualLoopification_Test_treeA(n - 1)
  end
end
Golden_MutualLoopification_Test_treeA = function(n)
  if n == 0 then
    return 1
  else
    return 1 + Golden_MutualLoopification_Test_treeB(n - 1)
  end
end
local Golden_MutualLoopification_Test_ticktock = function(n)
  local tock_S_w
  local tick_S_w
  tock_S_w = function(acc, k)
    if k == 0 then return acc else return tick_S_w(acc + 3, k - 1) end
  end
  tick_S_w = function(acc0, k0)
    if k0 == 0 then return acc0 else return tock_S_w(acc0 + 1, k0 - 1) end
  end
  return tick_S_w(0, n)
end
local Golden_MutualLoopification_Test_stepOther_S_w
local Golden_MutualLoopification_Test_stepSelf_S_w = function(acc, n)
  while true do
    if n == 0 then
      return acc
    elseif not(n < 10) and n ~= 10 then
      acc, n = acc + 10, n - 10
    else
      return Golden_MutualLoopification_Test_stepOther_S_w(acc, n)
    end
  end
end
M.Golden_MutualLoopification_Test_stepSelf = function(stepSelf_S_p1)
  return function(stepSelf_S_p2)
    return Golden_MutualLoopification_Test_stepSelf_S_w(stepSelf_S_p1, stepSelf_S_p2)
  end
end
Golden_MutualLoopification_Test_stepOther_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_MutualLoopification_Test_stepSelf_S_w(acc + 1, n - 1)
  end
end
M.Golden_MutualLoopification_Test_stepOther = function(stepOther_S_p1)
  return function(stepOther_S_p2)
    return Golden_MutualLoopification_Test_stepOther_S_w(stepOther_S_p1, stepOther_S_p2)
  end
end
local Golden_MutualLoopification_Test_isEven
local Golden_MutualLoopification_Test_isOdd = function(n)
  return n ~= 0 and Golden_MutualLoopification_Test_isEven(n - 1)
end
Golden_MutualLoopification_Test_isEven = function(n)
  return n == 0 or Golden_MutualLoopification_Test_isOdd(n - 1)
end
local Golden_MutualLoopification_Test_green_S_w
local Golden_MutualLoopification_Test_red_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_MutualLoopification_Test_green_S_w(acc + 1, n - 1)
  end
end
M.Golden_MutualLoopification_Test_red = function(red_S_p1)
  return function(red_S_p2)
    return Golden_MutualLoopification_Test_red_S_w(red_S_p1, red_S_p2)
  end
end
local Golden_MutualLoopification_Test_blue_S_w
Golden_MutualLoopification_Test_green_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_MutualLoopification_Test_blue_S_w(acc + 1, n - 1)
  end
end
M.Golden_MutualLoopification_Test_green = function(green_S_p1)
  return function(green_S_p2)
    return Golden_MutualLoopification_Test_green_S_w(green_S_p1, green_S_p2)
  end
end
Golden_MutualLoopification_Test_blue_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_MutualLoopification_Test_red_S_w(acc + 1, n - 1)
  end
end
M.Golden_MutualLoopification_Test_blue = function(blue_S_p1)
  return function(blue_S_p2)
    return Golden_MutualLoopification_Test_blue_S_w(blue_S_p1, blue_S_p2)
  end
end
return (function()
  local _ = Golden_MutualLoopification_Test_logShow(Golden_MutualLoopification_Test_isEven(10))()
  local _ = Golden_MutualLoopification_Test_logShow(Golden_MutualLoopification_Test_isOdd(7))()
  local _ = Golden_MutualLoopification_Test_logShow1(Golden_MutualLoopification_Test_zigzag_S_w(0, 3))()
  local _ = Golden_MutualLoopification_Test_logShow1(Golden_MutualLoopification_Test_red_S_w(0, 10))()
  local _ = Golden_MutualLoopification_Test_logShow1(Golden_MutualLoopification_Test_stepSelf_S_w(0, 25))()
  local _ = Golden_MutualLoopification_Test_logShow1(Golden_MutualLoopification_Test_treeA(5))()
  return Golden_MutualLoopification_Test_logShow1(Golden_MutualLoopification_Test_ticktock(5))()
end)()
