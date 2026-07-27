local function PSLUA_object_update(o, patches)
  local o_copy = {}
  for k, v in pairs(o) do
    local patch_v = patches[k]
    if patch_v ~= nil then o_copy[k] = patch_v else o_copy[k] = v end
  end
  return o_copy
end
local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_ScalarReplacement_Test_wholeValue = function(n)
  local r = { a = n, b = n + 1 }
  local s = (function()
    if r.a >= 0 and r.a ~= 0 then
      return r
    else
      return PSLUA_object_update(r, { a = 0 - r.a })
    end
  end)()
  return s.a + s.b
end
M.Golden_ScalarReplacement_Test_fieldwise = function(n) return n + 1 + n * 2 end
M.Golden_ScalarReplacement_Test_defaults = function(n) return n + 2 + n end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(31))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(12))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(14))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_ScalarReplacement_Test_wholeValue(5)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_ScalarReplacement_Test_wholeValue(-3)))()
end)()
