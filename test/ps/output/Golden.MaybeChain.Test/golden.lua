local M = {}
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
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
M.Golden_MaybeChain_Test_identity = function(x_S_313) return x_S_313 end
M.Golden_MaybeChain_Test_map_S_w = function(v_S_308, v1_S_309)
  if "Data.Maybe∷Maybe.Just" == v1_S_309["$ctor"] then
    return M.Data_Maybe_Just(v_S_308(v1_S_309.value0))
  else
    return M.Data_Maybe_Nothing
  end
end
return (function()
  local Data_Maybe_maybe_S_w, Data_Maybe_Just, Data_Maybe_Nothing, Data_Show_foreign, Effect_Console_foreign, Golden_MaybeChain_Test_identity, Golden_MaybeChain_Test_map_S_w = M.Data_Maybe_maybe_S_w, M.Data_Maybe_Just, M.Data_Maybe_Nothing, M.Data_Show_foreign, M.Effect_Console_foreign, M.Golden_MaybeChain_Test_identity, M.Golden_MaybeChain_Test_map_S_w
  local _ = Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Data_Maybe_maybe_S_w(0, Golden_MaybeChain_Test_identity, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, Golden_MaybeChain_Test_map_S_w(function( x_S_0 )
    return x_S_0
  end, Data_Maybe_Nothing)))))()
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Data_Maybe_maybe_S_w(0, Golden_MaybeChain_Test_identity, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, Golden_MaybeChain_Test_map_S_w(function( x0_S_1 )
    return x0_S_1
  end, Data_Maybe_Just(42))))))()
end)()
