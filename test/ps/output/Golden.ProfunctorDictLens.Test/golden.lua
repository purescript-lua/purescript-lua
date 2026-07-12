local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
local Unsafe_Coerce_unsafeCoerce = Unsafe_Coerce_foreign.unsafeCoerce
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_ProfunctorDictLens_Test_unwrap = Unsafe_Coerce_unsafeCoerce
local Golden_ProfunctorDictLens_Test_Wrapped = function(x) return x end
M.Golden_ProfunctorDictLens_Test__Wrapped = function(dictProfunctor)
  return dictProfunctor.dimap(Golden_ProfunctorDictLens_Test_unwrap)(Golden_ProfunctorDictLens_Test_Wrapped)
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ProfunctorDictLens_Test_unwrap(Golden_ProfunctorDictLens_Test_unwrap(10) + 1)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ProfunctorDictLens_Test_unwrap(Golden_ProfunctorDictLens_Test_unwrap(10) * 2)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_ProfunctorDictLens_Test_unwrap(Unsafe_Coerce_unsafeCoerce(Unsafe_Coerce_unsafeCoerce(10) - 5))))()
end)()
