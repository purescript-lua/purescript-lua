local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
return {
  chainedNothing = (function()
    local v2_S_1 = (function()
      local v2_S_0 = (function()
        if "Data.Maybe∷Maybe.Just" == Data_Maybe_Nothing[1] then
          return { "Data.Maybe∷Maybe.Just", Data_Maybe_Nothing[2] }
        else
          return Data_Maybe_Nothing
        end
      end)()
      if "Data.Maybe∷Maybe.Nothing" == v2_S_0[1] then
        return Data_Maybe_Nothing
      else
        return { "Data.Maybe∷Maybe.Just", v2_S_0[2] }
      end
    end)()
    if "Data.Maybe∷Maybe.Nothing" == v2_S_1[1] then
      return 0
    else
      return v2_S_1[2]
    end
  end)(),
  chainedJust = 42
}
