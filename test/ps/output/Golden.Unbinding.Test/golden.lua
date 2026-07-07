local M = {}
M.Golden_Unbinding_Test_f_S_w = function() return 3 end
return {
  a = 1,
  b = 2,
  f = function(f_S_p1_S_0)
    return function(f_S_p2_S_1)
      return M.Golden_Unbinding_Test_f_S_w(f_S_p1_S_0, f_S_p2_S_1)
    end
  end,
  c = M.Golden_Unbinding_Test_f_S_w(1, M.Golden_Unbinding_Test_f_S_w(2, 1))
}
