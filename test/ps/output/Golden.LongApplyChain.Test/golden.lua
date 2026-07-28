local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_LongApplyChain_Test_compute = { "Data.Maybe∷Maybe.Just", 300 }
return Effect_Console_foreign.log((function()
  if "Data.Maybe∷Maybe.Just" == Golden_LongApplyChain_Test_compute[1] then
    return "(Just " .. Data_Show_foreign.showIntImpl(Golden_LongApplyChain_Test_compute[2]) .. ")"
  else
    return "Nothing"
  end
end)())()
