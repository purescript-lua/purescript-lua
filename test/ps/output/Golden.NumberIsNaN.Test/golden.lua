local Data_Semiring_foreign = {
  numAdd = function(x) return function(y) return x + y end end,
  numMul = function(x) return function(y) return x * y end end
}
local Data_Ring_foreign = {
  numSub = function(x) return function(y) return x - y end end
}
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
local Data_Ring_sub = function(dict) return dict.sub end
local Data_Ring_ringNumber = {
  sub = Data_Ring_foreign.numSub,
  Semiring0 = function()
    return {
      add = Data_Semiring_foreign.numAdd,
      zero = 0.0,
      mul = Data_Semiring_foreign.numMul,
      one = 1.0
    }
  end
}
local Golden_NumberIsNaN_Test_logShow = function(a_S_2)
  return Effect_Console_foreign.log((function()
    if a_S_2 then
      return "true"
    elseif false == a_S_2 then
      return "false"
    else
      return error("No patterns matched")
    end
  end)())
end
return (function()
  local _ = Golden_NumberIsNaN_Test_logShow(Data_Number_isNaN(Data_Number_nan))()
  local _ = Golden_NumberIsNaN_Test_logShow(Data_Number_isNaN(Data_Ring_sub(Data_Ring_ringNumber)((Data_Ring_ringNumber.Semiring0()).zero)(Data_Number_nan)))()
  local _ = Golden_NumberIsNaN_Test_logShow(Data_Number_isNaN(Data_Ring_sub(Data_Ring_ringNumber)(Data_Number_infinity)(Data_Number_infinity)))()
  local _ = Golden_NumberIsNaN_Test_logShow(Data_Number_isNaN(42.0))()
  return Golden_NumberIsNaN_Test_logShow(Data_Number_isNaN(Data_Number_infinity))()
end)()
