-- Curried application in a hot loop: every partial application allocates a
-- closure (an FNEW bytecode under LuaJIT, which aborts trace recording), so
-- the loop never gets JIT-compiled. The uncurried variant compiles to a
-- single trace.
return {
  n = 2e7,
  variants = {
    {
      name = "current",
      fn = function(n)
        local add = function(x)
          return function(y)
            return x + y
          end
        end
        local acc = 0
        for i = 1, n do
          acc = add(acc)(i)
        end
        return acc
      end,
    },
    {
      name = "ideal",
      fn = function(n)
        local add = function(x, y)
          return x + y
        end
        local acc = 0
        for i = 1, n do
          acc = add(acc, i)
        end
        return acc
      end,
    },
  },
}
