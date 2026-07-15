-- A step function returning a two-field product that every caller
-- immediately deconstructs. The current variant boxes the pair into a
-- table per call (a TNEW/TDUP per iteration, GC pressure in a hot loop);
-- the ideal variant returns the two components as Lua multiple values and
-- allocates nothing.
return {
  n = 1e7,
  variants = {
    {
      name = "current",
      fn = function(n)
        local step = function(s)
          return { s % 3, s + 1 }
        end
        local acc, s = 0, 0
        for _ = 1, n do
          local v = step(s)
          acc, s = acc + v[1], v[2]
        end
        return acc
      end,
    },
    {
      name = "ideal",
      fn = function(n)
        local step = function(s)
          return s % 3, s + 1
        end
        local acc, s = 0, 0
        for _ = 1, n do
          local a, s2 = step(s)
          acc, s = acc + a, s2
        end
        return acc
      end,
    },
  },
}
