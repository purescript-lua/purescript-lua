-- Constructor allocation plus tag match: the generated encoding keeps the
-- tag and the payload in the table's hash part, keyed by long strings,
-- versus an array-part encoding with a small-integer tag.
return {
  name = "ctor_match",
  n = 2e6,
  variants = {
    {
      name = "current",
      fn = function(n)
        local acc = 0
        for i = 1, n do
          local m = { ["$ctor"] = "Data.Maybe∷Maybe.Just", value0 = i }
          if "Data.Maybe∷Maybe.Just" == m["$ctor"] then
            acc = acc + m.value0
          end
        end
        return acc
      end,
    },
    {
      name = "ideal",
      fn = function(n)
        local acc = 0
        for i = 1, n do
          local m = { 1, i }
          if 1 == m[1] then
            acc = acc + m[2]
          end
        end
        return acc
      end,
    },
  },
}
