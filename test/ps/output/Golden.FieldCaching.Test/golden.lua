local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_FieldCaching_Test_logShow = function(a_S_2)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_2))
end
local Golden_FieldCaching_Test_weigh = function(x) return x * 2 + 1 end
local Golden_FieldCaching_Test_sumLoop_S_w = function(acc, n)
  while true do
    if n == 0 then
      return acc
    else
      acc, n = acc + Golden_FieldCaching_Test_weigh(n), n - 1
    end
  end
end
M.Golden_FieldCaching_Test_sumLoop = function(sumLoop_S_p1)
  return function(sumLoop_S_p2)
    return Golden_FieldCaching_Test_sumLoop_S_w(sumLoop_S_p1, sumLoop_S_p2)
  end
end
local Golden_FieldCaching_Test_single = function(n)
  return Golden_FieldCaching_Test_weigh(n)
end
local Golden_FieldCaching_Test_pair = function(n)
  return Golden_FieldCaching_Test_weigh(n) + Golden_FieldCaching_Test_weigh(n + 1)
end
local Golden_FieldCaching_Test_fibby = function(n)
  if n < 2 then
    return n
  else
    return Golden_FieldCaching_Test_weigh(n - 1) + Golden_FieldCaching_Test_weigh(n - 2)
  end
end
local Golden_FieldCaching_Test_apply2 = function(f) return f(2) end
local Golden_FieldCaching_Test_closed = function(x)
  return Golden_FieldCaching_Test_apply2(function(y)
    return Golden_FieldCaching_Test_weigh(x) + Golden_FieldCaching_Test_weigh(y)
  end)
end
return (function()
  local _ = Golden_FieldCaching_Test_logShow(Golden_FieldCaching_Test_pair(1))()
  local _ = Golden_FieldCaching_Test_logShow(Golden_FieldCaching_Test_single(10))()
  local _ = Golden_FieldCaching_Test_logShow(Golden_FieldCaching_Test_sumLoop_S_w(0, 4))()
  local _ = Golden_FieldCaching_Test_logShow(Golden_FieldCaching_Test_fibby(5))()
  return Golden_FieldCaching_Test_logShow(Golden_FieldCaching_Test_closed(5))()
end)()
