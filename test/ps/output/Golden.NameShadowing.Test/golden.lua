local M = {}
M.Golden_NameShadowing_Test_f = function(v)
  return function(v1)
    if 1 == v then return 1 else if 1 == v1 then return 2 else return 3 end end
  end
end
return {
  b = function(x_S_0)
    return function(x1_S_1)
      return M.Golden_NameShadowing_Test_f(M.Golden_NameShadowing_Test_f(x_S_0)(x1_S_1))(M.Golden_NameShadowing_Test_f(42)(1))
    end
  end,
  c = function(x_S_2)
    return function(x1_S_3)
      return M.Golden_NameShadowing_Test_f(x1_S_3)(x_S_2)
    end
  end
}
