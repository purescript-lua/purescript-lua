local M = {}
M.Data_Show_foreign = {
  showIntImpl = function(n) return tostring(n) end,
  showArrayImpl = function(f)
    return function(xs)
      local l = #(xs)
      local ss = {}
      for i = 1, l do ss[i] = f(xs[i]) end
      return "[" .. table.concat(ss, ",") .. "]"
    end
  end
}
M.Data_Functor_foreign = {
  arrayMap = function(f)
    return function(arr)
      local l = #(arr)
      local result = {}
      for i = 1, l do result[i] = f(arr[i]) end
      return result
    end
  end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Data_Show_showInt = { show = M.Data_Show_foreign.showIntImpl }
M.Effect_Console_logShow_S_w = function(dictShow, a)
  return M.Effect_Console_foreign.log(dictShow.show(a))
end
M.Golden_Uncurry_Test_eq_S_w = function(r1_S_201_S_218, r2_S_202_S_219)
  return r1_S_201_S_218 == r2_S_202_S_219
end
M.Golden_Uncurry_Test_add_S_w = function(x_S_191_S_220, y_S_192_S_221)
  return x_S_191_S_220 + y_S_192_S_221
end
M.Golden_Uncurry_Test_sub_S_w = function(x_S_187_S_213, y_S_188_S_214)
  return x_S_187_S_213 - y_S_188_S_214
end
M.Golden_Uncurry_Test_sumTo = function(m)
  local go_S_w
  go_S_w = function(acc, n)
    local Golden_Uncurry_Test_add_S_w, Golden_Uncurry_Test_eq_S_w, Golden_Uncurry_Test_sub_S_w = M.Golden_Uncurry_Test_add_S_w, M.Golden_Uncurry_Test_eq_S_w, M.Golden_Uncurry_Test_sub_S_w
    while true do
      if Golden_Uncurry_Test_eq_S_w(n, 0) then
        return acc
      else
        acc, n = Golden_Uncurry_Test_add_S_w(acc, n), Golden_Uncurry_Test_sub_S_w(n, 1)
      end
    end
  end
  return go_S_w(0, m)
end
M.Golden_Uncurry_Test_oddSteps_S_w = function(acc, n)
  if M.Golden_Uncurry_Test_eq_S_w(n, 0) then
    return acc
  else
    return M.Golden_Uncurry_Test_evenSteps_S_w(M.Golden_Uncurry_Test_add_S_w(acc, 1), M.Golden_Uncurry_Test_sub_S_w(n, 1))
  end
end
M.Golden_Uncurry_Test_oddSteps = function(oddSteps_S_p1)
  return function(oddSteps_S_p2)
    return M.Golden_Uncurry_Test_oddSteps_S_w(oddSteps_S_p1, oddSteps_S_p2)
  end
end
M.Golden_Uncurry_Test_evenSteps_S_w = function(acc, n)
  if M.Golden_Uncurry_Test_eq_S_w(n, 0) then
    return acc
  else
    return M.Golden_Uncurry_Test_oddSteps_S_w(M.Golden_Uncurry_Test_add_S_w(acc, 1), M.Golden_Uncurry_Test_sub_S_w(n, 1))
  end
end
M.Golden_Uncurry_Test_evenSteps = function(evenSteps_S_p1)
  return function(evenSteps_S_p2)
    return M.Golden_Uncurry_Test_evenSteps_S_w(evenSteps_S_p1, evenSteps_S_p2)
  end
end
M.Golden_Uncurry_Test_alwaysFirst_S_w = function(x) return x end
M.Golden_Uncurry_Test_adderOf_S_w = function(x, y)
  return function(add_S_p2_S_229)
    local Golden_Uncurry_Test_add_S_w = M.Golden_Uncurry_Test_add_S_w
    return Golden_Uncurry_Test_add_S_w(Golden_Uncurry_Test_add_S_w(x, y), add_S_p2_S_229)
  end
end
M.Golden_Uncurry_Test_add3_S_w = function(x, y, z)
  local Golden_Uncurry_Test_add_S_w = M.Golden_Uncurry_Test_add_S_w
  return Golden_Uncurry_Test_add_S_w(Golden_Uncurry_Test_add_S_w(x, y), z)
end
M.Golden_Uncurry_Test_add3 = function(add3_S_p1)
  return function(add3_S_p2)
    return function(add3_S_p3)
      return M.Golden_Uncurry_Test_add3_S_w(add3_S_p1, add3_S_p2, add3_S_p3)
    end
  end
end
M.Golden_Uncurry_Test_inc = function(add3_S_p3_S_234)
  return M.Golden_Uncurry_Test_add3_S_w(1, 0, add3_S_p3_S_234)
end
return (function()
  local Effect_Console_logShow_S_w, Data_Show_showInt, Golden_Uncurry_Test_add3_S_w, Data_Show_foreign, Golden_Uncurry_Test_adderOf_S_w, Golden_Uncurry_Test_alwaysFirst_S_w = M.Effect_Console_logShow_S_w, M.Data_Show_showInt, M.Golden_Uncurry_Test_add3_S_w, M.Data_Show_foreign, M.Golden_Uncurry_Test_adderOf_S_w, M.Golden_Uncurry_Test_alwaysFirst_S_w
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(1, 2, 3))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(4, 5, 6))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(10, 1, 2))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(1, 0, 41))()
  local _ = Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showArrayImpl(Data_Show_foreign.showIntImpl)
  }, M.Data_Functor_foreign.arrayMap(function(add3_S_p3_S_247)
    return M.Golden_Uncurry_Test_add3_S_w(1, 2, add3_S_p3_S_247)
  end)({ [1] = 1, [2] = 2, [3] = 3 }))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, M.Golden_Uncurry_Test_evenSteps_S_w(0, 10))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, M.Golden_Uncurry_Test_oddSteps_S_w(0, 7))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    local go_S_w_S_251
    go_S_w_S_251 = function(acc_S_252, n_S_253)
      local Golden_Uncurry_Test_add_S_w, Golden_Uncurry_Test_eq_S_w, Golden_Uncurry_Test_sub_S_w = M.Golden_Uncurry_Test_add_S_w, M.Golden_Uncurry_Test_eq_S_w, M.Golden_Uncurry_Test_sub_S_w
      while true do
        if Golden_Uncurry_Test_eq_S_w(n_S_253, 0) then
          return acc_S_252
        else
          acc_S_252, n_S_253 = Golden_Uncurry_Test_add_S_w(acc_S_252, n_S_253), Golden_Uncurry_Test_sub_S_w(n_S_253, 1)
        end
      end
    end
    return go_S_w_S_251(0, 10)
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    local go_S_w_S_256
    go_S_w_S_256 = function(acc_S_257, n_S_258)
      local Golden_Uncurry_Test_add_S_w, Golden_Uncurry_Test_eq_S_w, Golden_Uncurry_Test_sub_S_w = M.Golden_Uncurry_Test_add_S_w, M.Golden_Uncurry_Test_eq_S_w, M.Golden_Uncurry_Test_sub_S_w
      while true do
        if Golden_Uncurry_Test_eq_S_w(n_S_258, 0) then
          return acc_S_257
        else
          acc_S_257, n_S_258 = Golden_Uncurry_Test_add_S_w(acc_S_257, n_S_258), Golden_Uncurry_Test_sub_S_w(n_S_258, 1)
        end
      end
    end
    return go_S_w_S_256(0, 100)
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_adderOf_S_w(1, 2)(3))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_adderOf_S_w(2, 3)(4))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_alwaysFirst_S_w(7, 8))()
  return Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_alwaysFirst_S_w(9, 10))()
end)()
