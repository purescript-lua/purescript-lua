local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_LongReaderBind_Test_go = function(r_S_0)
  return r_S_0 + r_S_0 + r_S_0
end
local Golden_LongReaderBind_Test_compute = 9
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_LongReaderBind_Test_compute))()
