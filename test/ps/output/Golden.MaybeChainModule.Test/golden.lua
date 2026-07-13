local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
local Data_Maybe_Just = function(value0)
  return { "Data.Maybe∷Maybe.Just", value0 }
end
local Data_Maybe_maybe_S_w = function(v, v1, v2)
  local _S_cse292 = v2[1]
  if "Data.Maybe∷Maybe.Nothing" == _S_cse292 then
    return v
  elseif "Data.Maybe∷Maybe.Just" == _S_cse292 then
    return v1(v2[2])
  else
    return error("No patterns matched")
  end
end
local Golden_MaybeChainModule_Test_identity = function(x_S_287)
  return x_S_287
end
local Golden_MaybeChainModule_Test_map_S_w = function(v_S_284, v1_S_285)
  if "Data.Maybe∷Maybe.Just" == v1_S_285[1] then
    return Data_Maybe_Just(v_S_284(v1_S_285[2]))
  else
    return Data_Maybe_Nothing
  end
end
return {
  chainedNothing = Data_Maybe_maybe_S_w(0, Golden_MaybeChainModule_Test_identity, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, Golden_MaybeChainModule_Test_map_S_w(function( x_S_1 )
    return x_S_1
  end, Data_Maybe_Nothing))),
  chainedJust = Data_Maybe_maybe_S_w(0, Golden_MaybeChainModule_Test_identity, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, Golden_MaybeChainModule_Test_map_S_w(function( x_S_0 )
    return x_S_0
  end, Data_Maybe_Just(42))))
}
