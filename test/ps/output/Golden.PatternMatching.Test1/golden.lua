return {
  Zero = { "Golden.PatternMatching.Test1∷N.Zero" },
  Succ = function(value0_S_0)
    return { "Golden.PatternMatching.Test1∷N.Succ", value0_S_0 }
  end,
  Num = function(value0_S_1)
    return { "Golden.PatternMatching.Test1∷E.Num", value0_S_1 }
  end,
  Not = function(value0_S_2)
    return { "Golden.PatternMatching.Test1∷E.Not", value0_S_2 }
  end,
  pat = function(e_S_0)
    local _S_cse0 = e_S_0[2]
    local _S_cse1 = e_S_0[1]
    if "Golden.PatternMatching.Test1∷E.Not" == _S_cse1 then
      if "Golden.PatternMatching.Test1∷E.Num" == _S_cse0[1] then
        if "Golden.PatternMatching.Test1∷N.Succ" == _S_cse0[2][1] then
          return 1
        elseif "Golden.PatternMatching.Test1∷N.Zero" == _S_cse0[2][1] then
          return 2
        else
          return 6
        end
      elseif "Golden.PatternMatching.Test1∷E.Not" == _S_cse0[1] then
        if "Golden.PatternMatching.Test1∷E.Num" == _S_cse0[2][1] then
          if "Golden.PatternMatching.Test1∷N.Succ" == _S_cse0[2][2][1] then
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
    elseif "Golden.PatternMatching.Test1∷E.Num" == _S_cse1 then
      if "Golden.PatternMatching.Test1∷N.Succ" == _S_cse0[1] then
        return 4
      else
        return 5
      end
    else
      return 6
    end
  end,
  T = function(value0_S_3)
    return function(value1_S_0) return { value0_S_3, value1_S_0 } end
  end,
  fst = function(v_S_0) return v_S_0[1] end,
  snd = function(v_S_1) return v_S_1[2] end
}
