local Golden_PatternMatching_Test2_bat = function(n)
  while true do
    if "Golden.PatternMatching.Test1∷N.Zero" == n["$ctor"] then
      return 1
    elseif "Golden.PatternMatching.Test1∷N.Succ" == n["$ctor"] then
      n = n.value0
    else
      return error("No patterns matched")
    end
  end
end
return {
  Zero = { ["$ctor"] = "Golden.PatternMatching.Test2∷N.Zero" },
  Succ = function(value0)
    return {
      ["$ctor"] = "Golden.PatternMatching.Test2∷N.Succ",
      value0 = value0
    }
  end,
  Add = function(value0)
    return function(value1)
      return {
        ["$ctor"] = "Golden.PatternMatching.Test2∷N.Add",
        value0 = value0,
        value1 = value1
      }
    end
  end,
  Mul = function(value0)
    return function(value1)
      return {
        ["$ctor"] = "Golden.PatternMatching.Test2∷N.Mul",
        value0 = value0,
        value1 = value1
      }
    end
  end,
  pat = function(e_S_0)
    if "Golden.PatternMatching.Test2∷N.Add" == e_S_0["$ctor"] then
      if "Golden.PatternMatching.Test2∷N.Zero" == e_S_0.value1["$ctor"] then
        if "Golden.PatternMatching.Test2∷N.Add" == e_S_0.value0["$ctor"] then
          return 1
        elseif "Golden.PatternMatching.Test2∷N.Mul" == e_S_0.value0["$ctor"] then
          return 2
        else
          return 5
        end
      elseif "Golden.PatternMatching.Test2∷N.Mul" == e_S_0.value1["$ctor"] then
        return 3
      elseif "Golden.PatternMatching.Test2∷N.Add" == e_S_0.value1["$ctor"] then
        return 4
      elseif "Golden.PatternMatching.Test2∷N.Zero" == e_S_0.value1["$ctor"] then
        return 5
      else
        return 6
      end
    else
      return 6
    end
  end,
  bat = Golden_PatternMatching_Test2_bat
}
