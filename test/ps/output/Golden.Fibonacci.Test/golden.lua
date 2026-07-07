local M = {}
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end
}
M.Data_Ring_foreign = {
  intSub = function(x) return function(y) return x - y end end
}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_Fibonacci_Test_fib = function(v)
  if 0 == v then
    return 0
  elseif 1 == v then
    return 1
  else
    return M.Data_Semiring_foreign.intAdd(M.Golden_Fibonacci_Test_fib(M.Data_Ring_foreign.intSub(v)(1)))(M.Golden_Fibonacci_Test_fib(M.Data_Ring_foreign.intSub(v)(2)))
  end
end
return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(M.Golden_Fibonacci_Test_fib(32)))()
