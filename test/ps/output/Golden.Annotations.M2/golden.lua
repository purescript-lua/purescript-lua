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
    local v_S_2 = (function()
      local v_S_4 = (function()
        if 1 == i_S_0 then return 2 else return i_S_0 end
      end)()
      if 1 == v_S_4 then return 2 else return v_S_4 end
    end)()
    if 1 == v_S_2 then return 2 else return v_S_2 end
  end,
  inlineIntoMe2 = M.Golden_Annotations_M1_foreign.dontInlineClosure(M.Golden_Annotations_M1_foreign.inlineMeLambda(M.Golden_Annotations_M1_foreign.inlineMeLambda(17)))
}
