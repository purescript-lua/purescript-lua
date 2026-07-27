local function PSLUA_object_update(o, patches)
  local o_copy = {}
  for k, v in pairs(o) do
    local patch_v = patches[k]
    if patch_v ~= nil then o_copy[k] = patch_v else o_copy[k] = v end
  end
  return o_copy
end
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Semiring_semiringInt = {
  add = function(x_S_0) return function(y_S_0) return x_S_0 + y_S_0 end end,
  zero = 0,
  mul = function(x_S_1) return function(y_S_1) return x_S_1 * y_S_1 end end,
  one = 1
}
local Data_Ring_sub = function(dict) return dict.sub end
local Data_Ring_ringInt = {
  sub = function(x_S_2) return function(y_S_2) return x_S_2 - y_S_2 end end,
  Semiring0 = function() return Data_Semiring_semiringInt end
}
local Golden_ScalarReplacement_Test_logShow = function(a_S_0)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_0))
end
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
local Golden_ScalarReplacement_Test_fieldwise = function(n)
  local r = { width = n + 1, height = n * 2 }
  return r.width + r.height
end
local Golden_ScalarReplacement_Test_defaults = function(n)
  local opts = { verbose = 1, level = n }
  local chosen = PSLUA_object_update(opts, { verbose = 2 })
  return opts.level + chosen.verbose + chosen.level
end
local Golden_ScalarReplacement_Test_chained_S_w = function(a, b)
  local r0 = { x = a, y = 0, z = 0 }
  local r1 = PSLUA_object_update(r0, { y = b })
  local r2 = PSLUA_object_update(r1, { z = a + b })
  return r2.x + r2.y + r2.z
end
return (function()
  local _ = Golden_ScalarReplacement_Test_logShow(Golden_ScalarReplacement_Test_fieldwise(10))()
  local _ = Golden_ScalarReplacement_Test_logShow(Golden_ScalarReplacement_Test_defaults(5))()
  local _ = Golden_ScalarReplacement_Test_logShow(Golden_ScalarReplacement_Test_chained_S_w(3, 4))()
  local _ = Golden_ScalarReplacement_Test_logShow(Golden_ScalarReplacement_Test_wholeValue(5))()
  return Golden_ScalarReplacement_Test_logShow(Golden_ScalarReplacement_Test_wholeValue(Data_Ring_sub(Data_Ring_ringInt)((Data_Ring_ringInt.Semiring0()).zero)(3)))()
end)()
