local M = {}
M.Golden_LongReaderBind_Test_go = function(r_S_0)
  return r_S_0 + r_S_0 + r_S_0
end
return (function(s) return function() print(s) end end)((function(n)
  return tostring(n)
end)(9))()
