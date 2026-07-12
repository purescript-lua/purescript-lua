return {
  Zero = { "Golden.PatternMatching.Test1∷N.Zero" },
  Succ = function(value0)
    return { "Golden.PatternMatching.Test1∷N.Succ", value0 }
  end,
  Num = function(value0)
    return { "Golden.PatternMatching.Test1∷E.Num", value0 }
  end,
  Not = function(value0)
    return { "Golden.PatternMatching.Test1∷E.Not", value0 }
  end,
  pat = function(e_S_2)
    if "Golden.PatternMatching.Test1∷E.Not" == e_S_2[1] then
      if "Golden.PatternMatching.Test1∷E.Num" == e_S_2[2][1] then
        if "Golden.PatternMatching.Test1∷N.Succ" == e_S_2[2][2][1] then
          return 1
        elseif "Golden.PatternMatching.Test1∷N.Zero" == e_S_2[2][2][1] then
          return 2
        else
          return 6
        end
      elseif "Golden.PatternMatching.Test1∷E.Not" == e_S_2[2][1] then
        if "Golden.PatternMatching.Test1∷E.Num" == e_S_2[2][2][1] then
          if "Golden.PatternMatching.Test1∷N.Succ" == e_S_2[2][2][2][1] then
            return 3
          else
            return 6
          end
        else
          return 6
        end
      else
        return 6
      end
    elseif "Golden.PatternMatching.Test1∷E.Num" == e_S_2[1] then
      if "Golden.PatternMatching.Test1∷N.Succ" == e_S_2[2][1] then
        return 4
      else
        return 5
      end
    else
      return 6
    end
  end,
  T = function(value0)
    return function(value1) return { value0, value1 } end
  end,
  fst = function(v_S_0) return v_S_0[1] end,
  snd = function(v_S_3) return v_S_3[2] end
}
