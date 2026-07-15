local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_LongReaderBind_Test_add_S_w = function(x_S_506, y_S_507)
  return x_S_506 + y_S_507
end
M.Golden_LongReaderBind_Test_go = function(r_S_556)
  return Golden_LongReaderBind_Test_add_S_w(Golden_LongReaderBind_Test_add_S_w(r_S_556, r_S_556), r_S_556)
end
local Golden_LongReaderBind_Test_compute = Unsafe_Coerce_foreign.unsafeCoerce(Golden_LongReaderBind_Test_add_S_w(Golden_LongReaderBind_Test_add_S_w(3, 3), 3))
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_LongReaderBind_Test_compute))()
