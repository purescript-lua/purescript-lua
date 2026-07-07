-- Recursion with typeclass arithmetic: the same `fib` as the
-- Golden.Fibonacci.Test golden, linked as a module so the driver can call
-- it without going through stdout.
return {
  name = "fibonacci",
  artifact = "Bench.Fib",
  n = 30,
  drive = function(mod, n)
    return mod.fib(n)
  end,
  ideal = function(n)
    local function fib(v)
      if v == 0 then
        return 0
      end
      if v == 1 then
        return 1
      end
      return fib(v - 1) + fib(v - 2)
    end
    return fib(n)
  end,
}
