local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_MutualLoopification_Test_logShow = function(a_S_0)
  return Effect_Console_log((function()
    if a_S_0 then return "true" else return "false" end
  end)())
end
local Golden_MutualLoopification_Test_logShow1 = function(a_S_1)
  return Effect_Console_log(Data_Show_foreign.showIntImpl(a_S_1))
end
local Golden_MutualLoopification_Test_zigzag_S_w_S_loop = function( _S_sel0
, _S_a0
, _S_a1
, _S_a2 )
  while true do
    if _S_sel0 == 1 then
      local acc, n = _S_a0, _S_a1
      if n == 0 then
        return acc
      else
        _S_sel0, _S_a0, _S_a1, _S_a2 = 2, acc, n, 1
      end
    else
      local acc, n, d = _S_a0, _S_a1, _S_a2
      if n == 0 then
        return acc
      else
        _S_sel0, _S_a0, _S_a1, _S_a2 = 1, acc + d, n - 1, nil
      end
    end
  end
end
local Golden_MutualLoopification_Test_zigzag_S_w = function(acc, n)
  return Golden_MutualLoopification_Test_zigzag_S_w_S_loop(1, acc, n)
end
M.Golden_MutualLoopification_Test_zigzag = function(zigzag_S_p1)
  return function(zigzag_S_p2)
    return Golden_MutualLoopification_Test_zigzag_S_w(zigzag_S_p1, zigzag_S_p2)
  end
end
local Golden_MutualLoopification_Test_zag_S_w = function(acc, n, d)
  return Golden_MutualLoopification_Test_zigzag_S_w_S_loop(2, acc, n, d)
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
  local tock_S_w_S_loop
  local tock_S_w
  local acc0, k0
  tock_S_w_S_loop = function(_S_sel1, _S_a3, _S_a4)
    while true do
      if _S_sel1 == 1 then
        local acc, k = _S_a3, _S_a4
        if k == 0 then
          return acc
        else
          _S_sel1, _S_a3, _S_a4 = 2, acc + 3, k - 1
        end
      else
        local acc0, k0 = _S_a3, _S_a4
        if k0 == 0 then
          return acc0
        else
          _S_sel1, _S_a3, _S_a4 = 1, acc0 + 1, k0 - 1
        end
      end
    end
  end
  tock_S_w = function(acc, k) return tock_S_w_S_loop(1, acc, k) end
  acc0, k0 = 0, n
  return tock_S_w_S_loop(2, acc0, k0)
end
local Golden_MutualLoopification_Test_stepSelf_S_w_S_loop = function( _S_sel2
, _S_a5
, _S_a6 )
  while true do
    if _S_sel2 == 1 then
      local acc, n = _S_a5, _S_a6
      if n == 0 then
        return acc
      elseif n >= 10 and n ~= 10 then
        _S_sel2, _S_a5, _S_a6 = 1, acc + 10, n - 10
      else
        _S_sel2, _S_a5, _S_a6 = 2, acc, n
      end
    else
      local acc, n = _S_a5, _S_a6
      if n == 0 then
        return acc
      else
        _S_sel2, _S_a5, _S_a6 = 1, acc + 1, n - 1
      end
    end
  end
end
local Golden_MutualLoopification_Test_stepSelf_S_w = function(acc, n)
  return Golden_MutualLoopification_Test_stepSelf_S_w_S_loop(1, acc, n)
end
M.Golden_MutualLoopification_Test_stepSelf = function(stepSelf_S_p1)
  return function(stepSelf_S_p2)
    return Golden_MutualLoopification_Test_stepSelf_S_w(stepSelf_S_p1, stepSelf_S_p2)
  end
end
local Golden_MutualLoopification_Test_stepOther_S_w = function(acc, n)
  return Golden_MutualLoopification_Test_stepSelf_S_w_S_loop(2, acc, n)
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
local Golden_MutualLoopification_Test_red_S_w_S_loop = function( _S_sel3
, _S_a7
, _S_a8 )
  while true do
    if _S_sel3 == 1 then
      local acc, n = _S_a7, _S_a8
      if n == 0 then
        return acc
      else
        _S_sel3, _S_a7, _S_a8 = 2, acc + 1, n - 1
      end
    elseif _S_sel3 == 2 then
      local acc, n = _S_a7, _S_a8
      if n == 0 then
        return acc
      else
        _S_sel3, _S_a7, _S_a8 = 3, acc + 1, n - 1
      end
    else
      local acc, n = _S_a7, _S_a8
      if n == 0 then
        return acc
      else
        _S_sel3, _S_a7, _S_a8 = 1, acc + 1, n - 1
      end
    end
  end
end
local Golden_MutualLoopification_Test_red_S_w = function(acc, n)
  return Golden_MutualLoopification_Test_red_S_w_S_loop(1, acc, n)
end
M.Golden_MutualLoopification_Test_red = function(red_S_p1)
  return function(red_S_p2)
    return Golden_MutualLoopification_Test_red_S_w(red_S_p1, red_S_p2)
  end
end
local Golden_MutualLoopification_Test_green_S_w = function(acc, n)
  return Golden_MutualLoopification_Test_red_S_w_S_loop(2, acc, n)
end
M.Golden_MutualLoopification_Test_green = function(green_S_p1)
  return function(green_S_p2)
    return Golden_MutualLoopification_Test_green_S_w(green_S_p1, green_S_p2)
  end
end
local Golden_MutualLoopification_Test_blue_S_w = function(acc, n)
  return Golden_MutualLoopification_Test_red_S_w_S_loop(3, acc, n)
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
