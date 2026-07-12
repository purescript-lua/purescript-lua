-- Constructor allocation plus tag match: the generated encoding keeps the
-- tag string in the table's array slot 1 and the payload after it. The
-- superseded hash-part encoding (string keys, pre-#185) stays as the
-- baseline that motivated the switch, and the small-integer-tag variant
-- records the anti-result: an interned tag string compares by pointer, so
-- an integer tag buys nothing over it — the win is the positional layout.
return {
  n = 2e6,
  variants = {
    {
      name = "hash (old)",
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
      name = "array (current)",
      fn = function(n)
        local acc = 0
        for i = 1, n do
          local m = { "Data.Maybe∷Maybe.Just", i }
          if "Data.Maybe∷Maybe.Just" == m[1] then
            acc = acc + m[2]
          end
        end
        return acc
      end,
    },
    {
      name = "array, int tag",
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
