local M = {}
M.Golden_NameShadowing_Test_f_S_w = function(v, v1)
  if 1 == v then return 1 elseif 1 == v1 then return 2 else return 3 end
end
return {
  b = function(x_S_0)
    return function(x1_S_1)
      local Golden_NameShadowing_Test_f_S_w = M.Golden_NameShadowing_Test_f_S_w
      return Golden_NameShadowing_Test_f_S_w(Golden_NameShadowing_Test_f_S_w(x_S_0, x1_S_1), Golden_NameShadowing_Test_f_S_w(42, 1))
    end
  end,
  c = function(x_S_3)
    return function(x1_S_4)
      return M.Golden_NameShadowing_Test_f_S_w(x1_S_4, x_S_3)
    end
  end
}
