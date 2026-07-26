local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_Loopification_Test_logShow = function(a_S_0)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_0))
end
local Golden_Loopification_Test_sumTo_S_w = function(acc, n)
  while true do if n == 0 then return acc else acc, n = acc + n, n - 1 end end
end
M.Golden_Loopification_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return Golden_Loopification_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
local Golden_Loopification_Test_sumSquares = function(m)
  local acc, n
  acc, n = 0, m
  while true do
    if n == 0 then return acc else acc, n = acc + n * n, n - 1 end
  end
end
local Golden_Loopification_Test_sumCPS_S_w
Golden_Loopification_Test_sumCPS_S_w = function(n, k)
  if n == 0 then
    return k(0)
  else
    return Golden_Loopification_Test_sumCPS_S_w(n - 1, function(r)
      return k(r + n)
    end)
  end
end
M.Golden_Loopification_Test_sumCPS = function(sumCPS_S_p1)
  return function(sumCPS_S_p2)
    return Golden_Loopification_Test_sumCPS_S_w(sumCPS_S_p1, sumCPS_S_p2)
  end
end
local Golden_Loopification_Test_mc91
Golden_Loopification_Test_mc91 = function(n)
  while true do
    if not(n < 100) and n ~= 100 then
      return n - 10
    else
      n = Golden_Loopification_Test_mc91(n + 11)
    end
  end
end
local Golden_Loopification_Test_countdown = function(n)
  while true do if not(n < 0) and n ~= 0 then n = n - 1 else return 0 end end
end
local Golden_Loopification_Test_countDrop_S_w = function(n)
  while true do if n == 0 then return 0 else n = n - 1 end end
end
M.Golden_Loopification_Test_countDrop = function(countDrop_S_p1)
  return function(countDrop_S_p2)
    return Golden_Loopification_Test_countDrop_S_w(countDrop_S_p1, countDrop_S_p2)
  end
end
return (function()
  local _ = Golden_Loopification_Test_logShow(Golden_Loopification_Test_countdown(5))()
  local _ = Golden_Loopification_Test_logShow(Golden_Loopification_Test_sumTo_S_w(0, 10))()
  local _ = Golden_Loopification_Test_logShow(Golden_Loopification_Test_sumSquares(4))()
  local _ = Golden_Loopification_Test_logShow(Golden_Loopification_Test_mc91(1))()
  local _ = Golden_Loopification_Test_logShow(Golden_Loopification_Test_sumCPS_S_w(5, function( x_S_0 )
    return x_S_0
  end))()
  return Golden_Loopification_Test_logShow(Golden_Loopification_Test_countDrop_S_w(3, 99))()
end)()
