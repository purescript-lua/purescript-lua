-- Reaching a function through module-table fields on every call, the way
-- linked code does (M.Data_Semiring_foreign.intAdd), versus hoisting it
-- into a local once. Both variants call uncurried so the difference is the
-- field lookups alone.
return {
  name = "field_access",
  n = 1e7,
  variants = {
    {
      name = "current",
      fn = function(n)
        local M = {
          Data_Semiring_foreign = {
            intAdd = function(x, y)
              return x + y
            end,
          },
        }
        local acc = 0
        for i = 1, n do
          acc = M.Data_Semiring_foreign.intAdd(acc, i)
        end
        return acc
      end,
    },
    {
      name = "ideal",
      fn = function(n)
        local intAdd = function(x, y)
          return x + y
        end
        local acc = 0
        for i = 1, n do
          acc = intAdd(acc, i)
        end
        return acc
      end,
    },
  },
}
