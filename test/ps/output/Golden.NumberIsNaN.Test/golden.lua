local Data_Ring_foreign = {
  numSub = function(x) return function(y) return x - y end end
}
local Data_Ring_numSub = Data_Ring_foreign.numSub
local Data_Number_foreign = {
  nan = 0 / 0,
  isNaN = function(x) return x ~= x end,
  infinity = math.huge
}
local Data_Number_infinity = Data_Number_foreign.infinity
local Data_Number_isNaN = Data_Number_foreign.isNaN
local Data_Number_nan = Data_Number_foreign.nan
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
return (function()
  local _ = (function()
    local a_S_318 = Data_Number_isNaN(Data_Number_nan)
    return Effect_Console_log((function()
      if a_S_318 then
        return "true"
      elseif false == a_S_318 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_320 = Data_Number_isNaN(Data_Ring_numSub(0.0)(Data_Number_nan))
    return Effect_Console_log((function()
      if a_S_320 then
        return "true"
      elseif false == a_S_320 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_322 = Data_Number_isNaN(Data_Ring_numSub(Data_Number_infinity)(Data_Number_infinity))
    return Effect_Console_log((function()
      if a_S_322 then
        return "true"
      elseif false == a_S_322 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_323 = Data_Number_isNaN(42.0)
    return Effect_Console_log((function()
      if a_S_323 then
        return "true"
      elseif false == a_S_323 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_324 = Data_Number_isNaN(Data_Number_infinity)
    return Effect_Console_log((function()
      if a_S_324 then
        return "true"
      elseif false == a_S_324 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
