local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_Loopification_Test_sub_S_w = function(x_S_188_S_221, y_S_189_S_222)
  return x_S_188_S_221 - y_S_189_S_222
end
local Golden_Loopification_Test_sumTo_S_w = function(acc, n)
  while true do
    if n == 0 then
      return acc
    else
      acc, n = acc + n, Golden_Loopification_Test_sub_S_w(n, 1)
    end
  end
end
M.Golden_Loopification_Test_sumTo = function(sumTo_S_p1)
  return function(sumTo_S_p2)
    return Golden_Loopification_Test_sumTo_S_w(sumTo_S_p1, sumTo_S_p2)
  end
end
M.Golden_Loopification_Test_sumSquares = function(m)
  local go_S_w
  go_S_w = function(acc, n)
    while true do
      if n == 0 then
        return acc
      else
        acc, n = acc + n * n, Golden_Loopification_Test_sub_S_w(n, 1)
      end
    end
  end
  return go_S_w(0, m)
end
local Golden_Loopification_Test_sumCPS_S_w
Golden_Loopification_Test_sumCPS_S_w = function(n, k)
  if n == 0 then
    return k(0)
  else
    return Golden_Loopification_Test_sumCPS_S_w(Golden_Loopification_Test_sub_S_w(n, 1), function( r )
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
    if "Data.Ordering∷Ordering.GT" == (function()
      if n < 100 then
        return "Data.Ordering∷Ordering.LT"
      elseif n == 100 then
        return "Data.Ordering∷Ordering.EQ"
      else
        return "Data.Ordering∷Ordering.GT"
      end
    end)() then
      return Golden_Loopification_Test_sub_S_w(n, 10)
    else
      n = Golden_Loopification_Test_mc91(n + 11)
    end
  end
end
local Golden_Loopification_Test_countdown = function(n)
  while true do
    if "Data.Ordering∷Ordering.GT" == (function()
      if n < 0 then
        return "Data.Ordering∷Ordering.LT"
      elseif n == 0 then
        return "Data.Ordering∷Ordering.EQ"
      else
        return "Data.Ordering∷Ordering.GT"
      end
    end)() then
      n = Golden_Loopification_Test_sub_S_w(n, 1)
    else
      return 0
    end
  end
end
local Golden_Loopification_Test_countDrop_S_w = function(n)
  while true do
    if n == 0 then return 0 else n = Golden_Loopification_Test_sub_S_w(n, 1) end
  end
end
M.Golden_Loopification_Test_countDrop = function(countDrop_S_p1)
  return function(countDrop_S_p2)
    return Golden_Loopification_Test_countDrop_S_w(countDrop_S_p1, countDrop_S_p2)
  end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_Loopification_Test_countdown(5)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_Loopification_Test_sumTo_S_w(0, 10)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local go_S_w_S_264
    go_S_w_S_264 = function(acc_S_265, n_S_266)
      while true do
        if n_S_266 == 0 then
          return acc_S_265
        else
          acc_S_265, n_S_266 = acc_S_265 + n_S_266 * n_S_266, Golden_Loopification_Test_sub_S_w(n_S_266, 1)
        end
      end
    end
    return go_S_w_S_264(0, 4)
  end)()))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_Loopification_Test_mc91(1)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_Loopification_Test_sumCPS_S_w(5, function( x_S_228 )
    return x_S_228
  end)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_Loopification_Test_countDrop_S_w(3, 99)))()
end)()
