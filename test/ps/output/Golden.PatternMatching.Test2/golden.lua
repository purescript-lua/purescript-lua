local Golden_PatternMatching_Test2_bat = function(n)
  while true do
    if "Golden.PatternMatching.Test1∷N.Zero" == n[1] then
      return 1
    else
      n = n[2]
    end
  end
end
return {
  Zero = { "Golden.PatternMatching.Test2∷N.Zero" },
  Succ = function(value0_S_5)
    return { "Golden.PatternMatching.Test2∷N.Succ", value0_S_5 }
  end,
  Add = function(value0_S_3)
    return function(value1_S_4)
      return { "Golden.PatternMatching.Test2∷N.Add", value0_S_3, value1_S_4 }
    end
  end,
  Mul = function(value0_S_1)
    return function(value1_S_2)
      return { "Golden.PatternMatching.Test2∷N.Mul", value0_S_1, value1_S_2 }
    end
  end,
  pat = function(e_S_0)
    local _S_cse7 = e_S_0[2]
    local _S_cse6 = e_S_0[3]
    if "Golden.PatternMatching.Test2∷N.Add" == e_S_0[1] then
      if "Golden.PatternMatching.Test2∷N.Zero" == _S_cse6[1] then
        if "Golden.PatternMatching.Test2∷N.Add" == _S_cse7[1] then
          return 1
        elseif "Golden.PatternMatching.Test2∷N.Mul" == _S_cse7[1] then
          return 2
        else
          return 5
        end
      elseif "Golden.PatternMatching.Test2∷N.Mul" == _S_cse6[1] then
        return 3
      elseif "Golden.PatternMatching.Test2∷N.Add" == _S_cse6[1] then
        return 4
      else
        return 6
      end
    else
      return 6
    end
  end,
  bat = Golden_PatternMatching_Test2_bat
}
