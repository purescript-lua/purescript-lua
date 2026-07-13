local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_Fibonacci_Test_sub_S_w = function(x_S_208, y_S_209)
  return x_S_208 - y_S_209
end
local Golden_Fibonacci_Test_fib
Golden_Fibonacci_Test_fib = function(v)
  if 0 == v then
    return 0
  elseif 1 == v then
    return 1
  else
    return Golden_Fibonacci_Test_fib(Golden_Fibonacci_Test_sub_S_w(v, 1)) + Golden_Fibonacci_Test_fib(Golden_Fibonacci_Test_sub_S_w(v, 2))
  end
end
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_Fibonacci_Test_fib(32)))()
