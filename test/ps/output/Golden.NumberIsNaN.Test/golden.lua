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
    local a_S_2_S_325 = Data_Number_isNaN(Data_Number_nan)
    return Effect_Console_log((function()
      if a_S_2_S_325 then
        return "true"
      elseif false == a_S_2_S_325 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_327 = Data_Number_isNaN(Data_Ring_numSub(0.0)(Data_Number_nan))
    return Effect_Console_log((function()
      if a_S_2_S_327 then
        return "true"
      elseif false == a_S_2_S_327 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_329 = Data_Number_isNaN(Data_Ring_numSub(Data_Number_infinity)(Data_Number_infinity))
    return Effect_Console_log((function()
      if a_S_2_S_329 then
        return "true"
      elseif false == a_S_2_S_329 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  local _ = (function()
    local a_S_2_S_330 = Data_Number_isNaN(42.0)
    return Effect_Console_log((function()
      if a_S_2_S_330 then
        return "true"
      elseif false == a_S_2_S_330 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
  return (function()
    local a_S_2_S_331 = Data_Number_isNaN(Data_Number_infinity)
    return Effect_Console_log((function()
      if a_S_2_S_331 then
        return "true"
      elseif false == a_S_2_S_331 then
        return "false"
      else
        return error("No patterns matched")
      end
    end)())
  end)()()
end)()
