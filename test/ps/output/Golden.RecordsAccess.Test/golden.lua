local M = {}
M.Golden_RecordsAccess_Test_r = { x = 1, y = true }
return {
  r = M.Golden_RecordsAccess_Test_r,
  test1 = 1,
  test2 = function(v_S_0) return v_S_0.x end,
  test3 = function(v_S_1) return v_S_1.x end,
  test4 = function(v_S_3) return v_S_3.x end
}
