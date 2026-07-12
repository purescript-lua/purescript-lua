return {
  U = {},
  P3 = function(value0)
    return function(value1)
      return function(value2) return { value0, value1, value2 } end
    end
  end,
  PF = function(value0) return { value0 } end,
  S0 = { "Golden.DataDeclarations.Test1∷TSum.S0" },
  S1 = function(value0)
    return { "Golden.DataDeclarations.Test1∷TSum.S1", value0 }
  end,
  S2 = function(value0)
    return function(value1)
      return { "Golden.DataDeclarations.Test1∷TSum.S2", value0, value1 }
    end
  end,
  Nop = { "Golden.DataDeclarations.Test1∷Rec.Nop" },
  More = function(value0)
    return { "Golden.DataDeclarations.Test1∷Rec.More", value0 }
  end,
  CtorSameName = {}
}
