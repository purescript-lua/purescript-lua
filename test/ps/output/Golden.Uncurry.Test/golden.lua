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
local Effect_Console_log = function(s) return function() print(s) end end
local Data_Show_showInt = { show = Data_Show_showIntImpl }
local Data_Show_show = function(dict) return dict.show end
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_log(dictShow.show(a))
end
local Golden_Uncurry_Test_logShow = function(logShow_S_p2_S_0)
  return Effect_Console_log(Data_Show_showIntImpl(logShow_S_p2_S_0))
end
local Golden_Uncurry_Test_sumTo = function(m)
  local acc, n
  acc, n = 0, m
  while true do if n == 0 then return acc else acc, n = acc + n, n - 1 end end
end
local Golden_Uncurry_Test_oddSteps_S_w_S_loop = function(_S_sel0, _S_a0, _S_a1)
  while true do
    if _S_sel0 == 1 then
      local acc, n = _S_a0, _S_a1
      if n == 0 then
        return acc
      else
        _S_sel0, _S_a0, _S_a1 = 2, acc + 1, n - 1
      end
    else
      local acc, n = _S_a0, _S_a1
      if n == 0 then
        return acc
      else
        _S_sel0, _S_a0, _S_a1 = 1, acc + 1, n - 1
      end
    end
  end
end
local Golden_Uncurry_Test_oddSteps_S_w = function(acc, n)
  return Golden_Uncurry_Test_oddSteps_S_w_S_loop(1, acc, n)
end
M.Golden_Uncurry_Test_oddSteps = function(oddSteps_S_p1)
  return function(oddSteps_S_p2)
    return Golden_Uncurry_Test_oddSteps_S_w(oddSteps_S_p1, oddSteps_S_p2)
  end
end
local Golden_Uncurry_Test_evenSteps_S_w = function(acc, n)
  return Golden_Uncurry_Test_oddSteps_S_w_S_loop(2, acc, n)
end
M.Golden_Uncurry_Test_evenSteps = function(evenSteps_S_p1)
  return function(evenSteps_S_p2)
    return Golden_Uncurry_Test_evenSteps_S_w(evenSteps_S_p1, evenSteps_S_p2)
  end
end
local Golden_Uncurry_Test_alwaysFirst_S_w = function(x) return x end
local Golden_Uncurry_Test_adderOf_S_w = function(x, y)
  return function(y_S_0) return x + y + y_S_0 end
end
local Golden_Uncurry_Test_add3_S_w = function(x, y, z) return x + y + z end
local Golden_Uncurry_Test_add3 = function(add3_S_p1)
  return function(add3_S_p2)
    return function(add3_S_p3) return add3_S_p1 + add3_S_p2 + add3_S_p3 end
  end
end
local Golden_Uncurry_Test_inc = function(add3_S_p3_S_0)
  return 1 + add3_S_p3_S_0
end
return (function()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_add3_S_w(1, 2, 3))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_add3_S_w(4, 5, 6))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_add3_S_w(10, 1, 2))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_inc(41))()
  local _ = Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showArrayImpl(Data_Show_show(Data_Show_showInt))
  }, Data_Functor_foreign.arrayMap(Golden_Uncurry_Test_add3(1)(2))({
    [1] = 1,
    [2] = 2,
    [3] = 3
  }))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_evenSteps_S_w(0, 10))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_oddSteps_S_w(0, 7))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_sumTo(10))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_sumTo(100))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_adderOf_S_w(1, 2)(3))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_adderOf_S_w(2, 3)(4))()
  local _ = Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_alwaysFirst_S_w(7, 8))()
  return Golden_Uncurry_Test_logShow(Golden_Uncurry_Test_alwaysFirst_S_w(9, 10))()
end)()
