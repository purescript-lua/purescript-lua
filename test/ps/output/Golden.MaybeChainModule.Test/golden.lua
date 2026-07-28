local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
local Data_Maybe_Just = function(value0)
  return { "Data.Maybe∷Maybe.Just", value0 }
end
local Data_Maybe_maybe_S_w = function(v, v1, v2)
  if "Data.Maybe∷Maybe.Nothing" == v2[1] then return v else return v1(v2[2]) end
end
return {
  chainedNothing = Data_Maybe_maybe_S_w(0, function(x_S_0)
    return x_S_0
  end, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, (function()
    if "Data.Maybe∷Maybe.Just" == Data_Maybe_Nothing[1] then
      return { "Data.Maybe∷Maybe.Just", Data_Maybe_Nothing[2] }
    else
      return Data_Maybe_Nothing
    end
  end)())),
  chainedJust = Data_Maybe_maybe_S_w(0, function(x_S_1)
    return x_S_1
  end, Data_Maybe_maybe_S_w(Data_Maybe_Nothing, Data_Maybe_Just, {
    "Data.Maybe∷Maybe.Just",
    42
  }))
}
