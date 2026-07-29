local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_JoinPoints_Test_logShow = function(a_S_0)
  return Effect_Console_log(Data_Show_showIntImpl(a_S_0))
end
local Golden_JoinPoints_Test_negate = function(a_S_1) return 0 - a_S_1 end
local Golden_JoinPoints_Test_sumTriangles = function(m)
  local acc, n
  acc, n = 0, m
  while true do
    if n == 0 then return acc else acc, n = acc + n * (n + 1), n - 1 end
  end
end
local Golden_JoinPoints_Test_escaping = function(n)
  local go
  go = function(acc)
    while true do if acc < n then acc = acc + 1 else return acc end end
  end
  return function(m) return go(m) end
end
local Golden_JoinPoints_Test_collatzish = function(n)
  local acc, k
  if n >= 100 and n ~= 100 then acc, k = 0, n else acc, k = 1, n + 3 end
  while true do
    if k >= 0 and k ~= 0 then acc, k = acc + 1, k - 2 else return acc end
  end
end
local Golden_JoinPoints_Test_classify = function(n)
  local r
  if n >= 0 and n ~= 0 then r = n + 1 else r = 0 - n end
  return (r * 10 + r) * 2 - r
end
local Golden_JoinPoints_Test_chooseEff = function(n)
  local m
  if n >= 0 and n ~= 0 then m = n else m = 0 - n end
  return Effect_Console_log(Data_Show_showIntImpl(m * 2))
end
return (function()
  local _ = Golden_JoinPoints_Test_logShow(Golden_JoinPoints_Test_sumTriangles(4))()
  local _ = Golden_JoinPoints_Test_logShow(Golden_JoinPoints_Test_collatzish(10))()
  local _ = Golden_JoinPoints_Test_logShow(Golden_JoinPoints_Test_collatzish(200))()
  local _ = Golden_JoinPoints_Test_logShow(Golden_JoinPoints_Test_classify(3))()
  local _ = Golden_JoinPoints_Test_logShow(Golden_JoinPoints_Test_classify(Golden_JoinPoints_Test_negate(2)))()
  local _ = Golden_JoinPoints_Test_logShow(Golden_JoinPoints_Test_escaping(5)(2))()
  local _ = Golden_JoinPoints_Test_chooseEff(4)()
  return Golden_JoinPoints_Test_chooseEff(Golden_JoinPoints_Test_negate(3))()
end)()
