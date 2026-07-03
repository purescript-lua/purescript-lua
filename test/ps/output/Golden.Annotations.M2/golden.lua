local M = {}
M.Golden_Annotations_M1_foreign = (function()
  local step = 2
  return {
    dontInlineClosure = function(i)
        return i + step
      end,
    inlineMeLambda = function(i)
        return i + i
      end
  }
end)()
return {
  inlineIntoMe = function(i_S_0)
    if 1 == (function()
      if 1 == (function()
        if 1 == i_S_0 then return 2 else return i_S_0 end
      end)() then
        return 2
      else
        if 1 == i_S_0 then return 2 else return i_S_0 end
      end
    end)() then
      return 2
    else
      if 1 == (function()
        if 1 == i_S_0 then return 2 else return i_S_0 end
      end)() then
        return 2
      else
        if 1 == i_S_0 then return 2 else return i_S_0 end
      end
    end
  end,
  inlineIntoMe2 = M.Golden_Annotations_M1_foreign.dontInlineClosure(M.Golden_Annotations_M1_foreign.inlineMeLambda(M.Golden_Annotations_M1_foreign.inlineMeLambda(17)))
}
