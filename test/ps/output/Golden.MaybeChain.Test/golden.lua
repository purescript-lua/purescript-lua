local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
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
  end)()))()
  return Effect_Console_log(Data_Show_showIntImpl(42))()
end)()
