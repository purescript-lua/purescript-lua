local M = {}
M.Data_Maybe_Nothing = { ["$ctor"] = "Data.Maybe∷Maybe.Nothing" }
M.Data_Maybe_Just = function(value0)
  return { ["$ctor"] = "Data.Maybe∷Maybe.Just", value0 = value0 }
end
M.Data_Maybe_maybe_S_w = function(v, v1, v2)
  if "Data.Maybe∷Maybe.Nothing" == v2["$ctor"] then
    return v
  elseif "Data.Maybe∷Maybe.Just" == v2["$ctor"] then
    return v1(v2.value0)
  else
    return error("No patterns matched")
  end
end
M.Golden_MaybeChainModule_Test_identity = function(x_S_287) return x_S_287 end
M.Golden_MaybeChainModule_Test_map_S_w = function(v_S_284, v1_S_285)
  if "Data.Maybe∷Maybe.Just" == v1_S_285["$ctor"] then
    return M.Data_Maybe_Just(v_S_284(v1_S_285.value0))
  else
    return M.Data_Maybe_Nothing
  end
end
return {
  chainedNothing = M.Data_Maybe_maybe_S_w(0, M.Golden_MaybeChainModule_Test_identity, M.Data_Maybe_maybe_S_w(M.Data_Maybe_Nothing, M.Data_Maybe_Just, M.Golden_MaybeChainModule_Test_map_S_w(function( x_S_1 )
    return x_S_1
  end, M.Data_Maybe_Nothing))),
  chainedJust = M.Data_Maybe_maybe_S_w(0, M.Golden_MaybeChainModule_Test_identity, M.Data_Maybe_maybe_S_w(M.Data_Maybe_Nothing, M.Data_Maybe_Just, M.Golden_MaybeChainModule_Test_map_S_w(function( x_S_0 )
    return x_S_0
  end, M.Data_Maybe_Just(42))))
}
