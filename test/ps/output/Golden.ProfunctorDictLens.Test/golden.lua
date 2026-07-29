local M = {}
local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Data_Newtype_coerce = function(x_S_0) return x_S_0 end
local Golden_ProfunctorDictLens_Test_unwrap = Data_Newtype_coerce
local Golden_ProfunctorDictLens_Test_Wrapped = function(x) return x end
M.Golden_ProfunctorDictLens_Test__Wrapped = function(dictProfunctor)
  return dictProfunctor.dimap(Golden_ProfunctorDictLens_Test_unwrap)(Golden_ProfunctorDictLens_Test_Wrapped)
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ProfunctorDictLens_Test_unwrap(Golden_ProfunctorDictLens_Test_unwrap(10) + 1)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ProfunctorDictLens_Test_unwrap(Golden_ProfunctorDictLens_Test_unwrap(10) * 2)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_ProfunctorDictLens_Test_unwrap(5)))()
end)()
