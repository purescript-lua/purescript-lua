local M = {}
local Data_Show_foreign = {
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
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Data_Functor_foreign = {
  arrayMap = function(f)
    return function(arr)
      local l = #(arr)
      local result = {}
      for i = 1, l do result[i] = f(arr[i]) end
      return result
    end
  end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Show_showInt = { show = Data_Show_showIntImpl }
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
end
M.Golden_Uncurry_Test_sumTo = function(m)
  local go_S_w
  go_S_w = function(acc, n)
    while true do if n == 0 then return acc else acc, n = acc + n, n - 1 end end
  end
  return go_S_w(0, m)
end
local Golden_Uncurry_Test_evenSteps_S_w
local Golden_Uncurry_Test_oddSteps_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_Uncurry_Test_evenSteps_S_w(acc + 1, n - 1)
  end
end
M.Golden_Uncurry_Test_oddSteps = function(oddSteps_S_p1)
  return function(oddSteps_S_p2)
    return Golden_Uncurry_Test_oddSteps_S_w(oddSteps_S_p1, oddSteps_S_p2)
  end
end
Golden_Uncurry_Test_evenSteps_S_w = function(acc, n)
  if n == 0 then
    return acc
  else
    return Golden_Uncurry_Test_oddSteps_S_w(acc + 1, n - 1)
  end
end
M.Golden_Uncurry_Test_evenSteps = function(evenSteps_S_p1)
  return function(evenSteps_S_p2)
    return Golden_Uncurry_Test_evenSteps_S_w(evenSteps_S_p1, evenSteps_S_p2)
  end
end
local Golden_Uncurry_Test_alwaysFirst_S_w = function(x) return x end
local Golden_Uncurry_Test_adderOf_S_w = function(x, y)
  return function(y_S_229) return x + y + y_S_229 end
end
local Golden_Uncurry_Test_add3_S_w = function(x, y, z) return x + y + z end
M.Golden_Uncurry_Test_add3 = function(add3_S_p1)
  return function(add3_S_p2)
    return function(add3_S_p3)
      return Golden_Uncurry_Test_add3_S_w(add3_S_p1, add3_S_p2, add3_S_p3)
    end
  end
end
M.Golden_Uncurry_Test_inc = function(add3_S_p3_S_223)
  return Golden_Uncurry_Test_add3_S_w(1, 0, add3_S_p3_S_223)
end
return (function()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(1, 2, 3))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(4, 5, 6))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(10, 1, 2))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_add3_S_w(1, 0, 41))()
  local _ = Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showArrayImpl(Data_Show_showIntImpl)
  }, Data_Functor_foreign.arrayMap(function(add3_S_p3_S_258)
    return Golden_Uncurry_Test_add3_S_w(1, 2, add3_S_p3_S_258)
  end)({ [1] = 1, [2] = 2, [3] = 3 }))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_evenSteps_S_w(0, 10))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_oddSteps_S_w(0, 7))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    local go_S_w_S_262
    go_S_w_S_262 = function(acc_S_263, n_S_264)
      while true do
        if n_S_264 == 0 then
          return acc_S_263
        else
          acc_S_263, n_S_264 = acc_S_263 + n_S_264, n_S_264 - 1
        end
      end
    end
    return go_S_w_S_262(0, 10)
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    local go_S_w_S_273
    go_S_w_S_273 = function(acc_S_274, n_S_275)
      while true do
        if n_S_275 == 0 then
          return acc_S_274
        else
          acc_S_274, n_S_275 = acc_S_274 + n_S_275, n_S_275 - 1
        end
      end
    end
    return go_S_w_S_273(0, 100)
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_adderOf_S_w(1, 2)(3))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_adderOf_S_w(2, 3)(4))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_alwaysFirst_S_w(7, 8))()
  return Effect_Console_logShow_S_w(Data_Show_showInt, Golden_Uncurry_Test_alwaysFirst_S_w(9, 10))()
end)()
