local Golden_Fibonacci_Test_fib
Golden_Fibonacci_Test_fib = function(v)
  if 0 == v then
    return 0
  elseif 1 == v then
    return 1
  else
    return Golden_Fibonacci_Test_fib(v - 1) + Golden_Fibonacci_Test_fib(v - 2)
  end
end
return (function(s) return function() print(s) end end)((function(n)
  return tostring(n)
end)(Golden_Fibonacci_Test_fib(32)))()
