local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
local Data_Maybe_Just = function(value0)
  return { "Data.Maybe∷Maybe.Just", value0 }
end
local Data_Maybe_maybe_S_w = function(v, v1, v2)
  local _S_cse320 = v2[1]
  if "Data.Maybe∷Maybe.Nothing" == _S_cse320 then
    return v
  elseif "Data.Maybe∷Maybe.Just" == _S_cse320 then
    return v1(v2[2])
  else
    return error("No patterns matched")
  end
end
local Golden_MaybeChain_Test_identity = function(x_S_311) return x_S_311 end
local Golden_MaybeChain_Test_map_S_w = function(v_S_307, v1_S_308)
  if "Data.Maybe∷Maybe.Just" == v1_S_308[1] then
    return { "Data.Maybe∷Maybe.Just", (v_S_307(v1_S_308[2])) }
  else
    return Data_Maybe_Nothing
  end
end
return (function()
  local _S_cse321 = function(x_S_0) return x_S_0 end
  local _ = Effect_Console_log(Data_Show_showIntImpl(Data_Maybe_maybe_S_w(0, Golden_MaybeChain_Test_identity, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, Golden_MaybeChain_Test_map_S_w(_S_cse321, Data_Maybe_Nothing)))))()
  return Effect_Console_log(Data_Show_showIntImpl(Data_Maybe_maybe_S_w(0, Golden_MaybeChain_Test_identity, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, Golden_MaybeChain_Test_map_S_w(_S_cse321, {
    "Data.Maybe∷Maybe.Just",
    42
  })))))()
end)()
