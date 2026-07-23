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
  local _ = Effect_Console_log((function()
    if Data_Number_isNaN(Data_Number_nan) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Data_Number_isNaN(Data_Ring_numSub(0.0)(Data_Number_nan)) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Data_Number_isNaN(Data_Ring_numSub(Data_Number_infinity)(Data_Number_infinity)) then
      return "true"
    else
      return "false"
    end
  end)())()
  local _ = Effect_Console_log((function()
    if Data_Number_isNaN(42.0) then return "true" else return "false" end
  end)())()
  return Effect_Console_log((function()
    if Data_Number_isNaN(Data_Number_infinity) then
      return "true"
    else
      return "false"
    end
  end)())()
end)()
