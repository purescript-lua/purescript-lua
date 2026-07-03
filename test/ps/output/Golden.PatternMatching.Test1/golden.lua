return {
  Zero = { ["$ctor"] = "Golden.PatternMatching.Test1∷N.Zero" },
  Succ = function(value0)
    return {
      ["$ctor"] = "Golden.PatternMatching.Test1∷N.Succ",
      value0 = value0
    }
  end,
  Num = function(value0)
    return { ["$ctor"] = "Golden.PatternMatching.Test1∷E.Num", value0 = value0 }
  end,
  Not = function(value0)
    return { ["$ctor"] = "Golden.PatternMatching.Test1∷E.Not", value0 = value0 }
  end,
  pat = function(e_S_2)
    if "Golden.PatternMatching.Test1∷E.Not" == e_S_2["$ctor"] then
      if "Golden.PatternMatching.Test1∷E.Num" == e_S_2.value0["$ctor"] then
        if "Golden.PatternMatching.Test1∷N.Succ" == e_S_2.value0.value0["$ctor"] then
          return 1
        else
          if "Golden.PatternMatching.Test1∷N.Zero" == e_S_2.value0.value0["$ctor"] then
            return 2
          else
            return 6
          end
        end
      else
        if "Golden.PatternMatching.Test1∷E.Not" == e_S_2.value0["$ctor"] then
          if "Golden.PatternMatching.Test1∷E.Num" == e_S_2.value0.value0["$ctor"] then
            if "Golden.PatternMatching.Test1∷N.Succ" == e_S_2.value0.value0.value0["$ctor"] then
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
      end
    else
      if "Golden.PatternMatching.Test1∷E.Num" == e_S_2["$ctor"] then
        if "Golden.PatternMatching.Test1∷N.Succ" == e_S_2.value0["$ctor"] then
          return 4
        else
          return 5
        end
      else
        return 6
      end
    end
  end,
  T = function(value0)
    return function(value1)
      return {
        ["$ctor"] = "Golden.PatternMatching.Test1∷Tuple.T",
        value0 = value0,
        value1 = value1
      }
    end
  end,
  fst = function(v_S_0) return v_S_0.value0 end,
  snd = function(v_S_3) return v_S_3.value1 end
}
