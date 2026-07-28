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
  if "Data.Maybe∷Maybe.Nothing" == v2[1] then return v else return v1(v2[2]) end
end
return (function()
  local _S_cse0 = function(x_S_0) return x_S_0 end
  local _ = Effect_Console_log(Data_Show_showIntImpl(Data_Maybe_maybe_S_w(0, _S_cse0, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, (function(  )
    if "Data.Maybe∷Maybe.Just" == Data_Maybe_Nothing[1] then
      return { "Data.Maybe∷Maybe.Just", Data_Maybe_Nothing[2] }
    else
      return Data_Maybe_Nothing
    end
  end)()))))()
  return Effect_Console_log(Data_Show_showIntImpl(Data_Maybe_maybe_S_w(0, _S_cse0, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, {
    "Data.Maybe∷Maybe.Just",
    42
  }))))()
end)()
