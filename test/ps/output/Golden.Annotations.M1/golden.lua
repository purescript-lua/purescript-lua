local Golden_Annotations_M1_foreign = (function()
  local step = 2
  return {
    dontInlineClosure = function(i) return i + step end,
    inlineMeLambda = function(i) return i + i end
  }
end)()
return {
  inlineMe = function(v_S_0)
    if 1 == v_S_0 then return 2 else return v_S_0 end
  end,
  dontInlineClosure = Golden_Annotations_M1_foreign.dontInlineClosure,
  inlineMeLambda = Golden_Annotations_M1_foreign.inlineMeLambda
}
