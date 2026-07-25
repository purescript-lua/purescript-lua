local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_JoinPoints_Test_logShow = function(a_S_2)
  return Effect_Console_log(Data_Show_showIntImpl(a_S_2))
end
local Golden_JoinPoints_Test_negate = function(a_S_88) return 0 - a_S_88 end
local Golden_JoinPoints_Test_sumTriangles = function(m)
  local go_S_w
  go_S_w = function(acc, n)
    while true do
      if n == 0 then return acc else acc, n = acc + n * (n + 1), n - 1 end
    end
  end
  return go_S_w(0, m)
end
local Golden_JoinPoints_Test_escaping = function(n)
  local go
  go = function(acc)
    while true do if acc < n then acc = acc + 1 else return acc end end
  end
  return function(m) return go(m) end
end
local Golden_JoinPoints_Test_collatzish = function(n)
  local go_S_w
  go_S_w = function(acc, k)
    while true do
      if not(k < 0) and k ~= 0 then acc, k = acc + 1, k - 2 else return acc end
    end
  end
  if not(n < 100) and n ~= 100 then
    return go_S_w(0, n)
  else
    return go_S_w(1, n + 3)
  end
end
local Golden_JoinPoints_Test_classify = function(n)
  local finish = function(r) return (r * 10 + r) * 2 - r end
  if not(n < 0) and n ~= 0 then
    return finish(n + 1)
  else
    return finish(0 - n)
  end
end
local Golden_JoinPoints_Test_chooseEff = function(n)
  local report = function(m)
    return Effect_Console_log(Data_Show_showIntImpl(m * 2))
  end
  if not(n < 0) and n ~= 0 then return report(n) else return report(0 - n) end
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
