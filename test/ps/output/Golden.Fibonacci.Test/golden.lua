local M = {}
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_Fibonacci_Test_sub_S_w = function(x_S_185_S_208, y_S_186_S_209)
  return x_S_185_S_208 - y_S_186_S_209
end
M.Golden_Fibonacci_Test_fib = function(v)
  if 0 == v then
    return 0
  elseif 1 == v then
    return 1
  else
    return M.Golden_Fibonacci_Test_fib(M.Golden_Fibonacci_Test_sub_S_w(v, 1)) + M.Golden_Fibonacci_Test_fib(M.Golden_Fibonacci_Test_sub_S_w(v, 2))
  end
end
return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(M.Golden_Fibonacci_Test_fib(32)))()
