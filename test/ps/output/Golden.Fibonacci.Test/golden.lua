local M = {}
M.Data_Ring_foreign = {
  intSub = function(x) return function(y) return x - y end end
}
M.Golden_Fibonacci_Test_fib = function(v)
  if 0 == v then
    return 0
  else
    if 1 == v then
      return 1
    else
      return (function(x) return function(y) return x + y end end)(M.Golden_Fibonacci_Test_fib(M.Data_Ring_foreign.intSub(v)(1)))(M.Golden_Fibonacci_Test_fib(M.Data_Ring_foreign.intSub(v)(2)))
    end
  end
end
return (function(s) return function() print(s) end end)((function(n) return tostring(n) end)(M.Golden_Fibonacci_Test_fib(32)))()
