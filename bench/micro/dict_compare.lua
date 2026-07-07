-- Dictionary-driven comparison: `greaterThanOrEq ordInt` goes through a
-- dictionary table, a curried three-level call chain, an Ordering
-- constructor allocation and a tag match — versus the native `>=` the
-- whole dance stands for.
local LT = { ["$ctor"] = "Data.Ordering∷Ordering.LT" }
local EQ = { ["$ctor"] = "Data.Ordering∷Ordering.EQ" }
local GT = { ["$ctor"] = "Data.Ordering∷Ordering.GT" }
local M = {}
M.Data_Ord_ordInt = {
  compare = function(x)
    return function(y)
      if x < y then
        return LT
      elseif x == y then
        return EQ
      else
        return GT
      end
    end
  end,
}
M.Data_Ord_greaterThanOrEq = function(dictOrd)
  return function(a1)
    return function(a2)
      return dictOrd.compare(a1)(a2)["$ctor"] ~= "Data.Ordering∷Ordering.LT"
    end
  end
end

return {
  name = "dict_gte",
  n = 5e6,
  variants = {
    {
      name = "current",
      fn = function(n)
        local half = n / 2
        local count = 0
        for i = 1, n do
          if M.Data_Ord_greaterThanOrEq(M.Data_Ord_ordInt)(i)(half) then
            count = count + 1
          end
        end
        return count
      end,
    },
    {
      name = "ideal",
      fn = function(n)
        local half = n / 2
        local count = 0
        for i = 1, n do
          if i >= half then
            count = count + 1
          end
        end
        return count
      end,
    },
  },
}
