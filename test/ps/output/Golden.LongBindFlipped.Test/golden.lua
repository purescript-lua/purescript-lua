local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Golden_LongBindFlipped_Test_inc = function(x)
  return { "Data.Maybe∷Maybe.Just", x + 1 }
end
local Golden_LongBindFlipped_Test_compute = { "Data.Maybe∷Maybe.Just", 301 }
return (function(s) return function() print(s) end end)((function()
  if "Data.Maybe∷Maybe.Just" == Golden_LongBindFlipped_Test_compute[1] then
    return "(Just " .. Data_Show_foreign.showIntImpl(Golden_LongBindFlipped_Test_compute[2]) .. ")"
  else
    return "Nothing"
  end
end)())()
