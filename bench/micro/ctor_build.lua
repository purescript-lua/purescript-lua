-- Constructing a three-field data value in a hot loop. The curried variant
-- allocates a closure per field past the first (an FNEW under LuaJIT, which
-- aborts trace recording), so the loop never gets JIT-compiled. The ideal
-- variant builds the table directly and compiles to a single trace.
return {
  n = 1e7,
  variants = {
    {
      name = "current",
      fn = function(n)
        local V = function(a)
          return function(b)
            return function(c)
              return { "V", a, b, c }
            end
          end
        end
        local acc = 0
        for i = 1, n do
          local v = V(i)(i + 1)(i + 2)
          acc = acc + v[2] + v[3] + v[4]
        end
        return acc
      end,
    },
    {
      name = "ideal",
      fn = function(n)
        local acc = 0
        for i = 1, n do
          local v = { "V", i, i + 1, i + 2 }
          acc = acc + v[2] + v[3] + v[4]
        end
        return acc
      end,
    },
  },
}
