return {
  U = {},
  P3 = function(value0_S_0)
    return function(value1_S_0)
      return function(value2_S_0)
        return { value0_S_0, value1_S_0, value2_S_0 }
      end
    end
  end,
  PF = function(value0_S_1) return { value0_S_1 } end,
  S0 = { "Golden.DataDeclarations.Test1∷TSum.S0" },
  S1 = function(value0_S_2)
    return { "Golden.DataDeclarations.Test1∷TSum.S1", value0_S_2 }
  end,
  S2 = function(value0_S_3)
    return function(value1_S_1)
      return { "Golden.DataDeclarations.Test1∷TSum.S2", value0_S_3, value1_S_1 }
    end
  end,
  Nop = { "Golden.DataDeclarations.Test1∷Rec.Nop" },
  More = function(value0_S_4)
    return { "Golden.DataDeclarations.Test1∷Rec.More", value0_S_4 }
  end,
  CtorSameName = {}
}
