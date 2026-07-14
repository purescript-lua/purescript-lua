return {
  Zero = { "Golden.PatternMatching.Test1∷N.Zero" },
  Succ = function(value0_S_7)
    return { "Golden.PatternMatching.Test1∷N.Succ", value0_S_7 }
  end,
  Num = function(value0_S_6)
    return { "Golden.PatternMatching.Test1∷E.Num", value0_S_6 }
  end,
  Not = function(value0_S_5)
    return { "Golden.PatternMatching.Test1∷E.Not", value0_S_5 }
  end,
  pat = function(e_S_2)
    local _S_cse11 = e_S_2[2]
    local _S_cse10 = e_S_2[1]
    if "Golden.PatternMatching.Test1∷E.Not" == _S_cse10 then
      if "Golden.PatternMatching.Test1∷E.Num" == _S_cse11[1] then
        if "Golden.PatternMatching.Test1∷N.Succ" == _S_cse11[2][1] then
          return 1
        elseif "Golden.PatternMatching.Test1∷N.Zero" == _S_cse11[2][1] then
          return 2
        else
          return 6
        end
      elseif "Golden.PatternMatching.Test1∷E.Not" == _S_cse11[1] then
        if "Golden.PatternMatching.Test1∷E.Num" == _S_cse11[2][1] then
          if "Golden.PatternMatching.Test1∷N.Succ" == _S_cse11[2][2][1] then
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
    elseif "Golden.PatternMatching.Test1∷E.Num" == _S_cse10 then
      if "Golden.PatternMatching.Test1∷N.Succ" == _S_cse11[1] then
        return 4
      else
        return 5
      end
    else
      return 6
    end
  end,
  T = function(value0_S_8)
    return function(value1_S_9) return { value0_S_8, value1_S_9 } end
  end,
  fst = function(v_S_0) return v_S_0[1] end,
  snd = function(v_S_3) return v_S_3[2] end
}
