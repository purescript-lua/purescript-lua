local Record_Unsafe_foreign = {
  unsafeHas = function(l) return function(r) return r[l] ~= nil end end,
  unsafeGet = function(l) return function(r) return r[l] end end,
  unsafeSet = function(l)
    return function(value)
      return function(r)
        local copy = {}
        for key, val in pairs(r) do copy[key] = val end
        copy[l] = value
        return copy
      end
    end
  end,
  unsafeDelete = function(l)
    return function(r)
      local copy = {}
      for key, val in pairs(r) do if key ~= l then copy[key] = val end end
      return copy
    end
  end
}
local Record_Unsafe_unsafeDelete = Record_Unsafe_foreign.unsafeDelete
local Record_Unsafe_unsafeGet = Record_Unsafe_foreign.unsafeGet
local Record_Unsafe_unsafeHas = Record_Unsafe_foreign.unsafeHas
local Record_Unsafe_unsafeSet = Record_Unsafe_foreign.unsafeSet
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end
}
local Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
local Golden_RecordSurgery_Test_logShow = function(a_S_223)
  return Effect_Console_log(Data_Show_foreign.showIntImpl(a_S_223))
end
local Golden_RecordSurgery_Test_logShow1 = function(a_S_221)
  return Effect_Console_log((function()
    if a_S_221 then return "true" else return "false" end
  end)())
end
local Golden_RecordSurgery_Test_replaced = Record_Unsafe_unsafeSet("a")(3)({
  a = 1
})
local Golden_RecordSurgery_Test_present = Record_Unsafe_unsafeHas("a")({
  a = 1
})
local Golden_RecordSurgery_Test_inserted = Record_Unsafe_unsafeSet("b")(2)({
  a = 1
})
local Golden_RecordSurgery_Test_got = Record_Unsafe_unsafeGet("a")({ a = 42 })
local Golden_RecordSurgery_Test_deleted = Record_Unsafe_unsafeDelete("a")({
  a = 1,
  b = 2
})
local Golden_RecordSurgery_Test_coerced = Unsafe_Coerce_foreign.unsafeCoerce(7)
local Golden_RecordSurgery_Test_absent = Record_Unsafe_unsafeHas("z")({ a = 1 })
return (function()
  local ref_S_0 = Effect_Ref_foreign._new({ k = 9, n = 1 })()
  local dyn_S_1 = Effect_Ref_foreign.read(ref_S_0)()
  local _ = Golden_RecordSurgery_Test_logShow(Golden_RecordSurgery_Test_inserted.a + Golden_RecordSurgery_Test_inserted.b)()
  local _ = Golden_RecordSurgery_Test_logShow(Golden_RecordSurgery_Test_replaced.a)()
  local _ = Golden_RecordSurgery_Test_logShow(Golden_RecordSurgery_Test_deleted.b)()
  local _ = Golden_RecordSurgery_Test_logShow(Golden_RecordSurgery_Test_got)()
  local _ = Golden_RecordSurgery_Test_logShow1(Golden_RecordSurgery_Test_present)()
  local _ = Golden_RecordSurgery_Test_logShow1(Golden_RecordSurgery_Test_absent)()
  local _ = Golden_RecordSurgery_Test_logShow(Record_Unsafe_unsafeGet("k")(Record_Unsafe_unsafeSet("k")(Record_Unsafe_unsafeGet("k")(dyn_S_1) + 1)(dyn_S_1)))()
  local _ = Golden_RecordSurgery_Test_logShow1(Record_Unsafe_unsafeHas("k")(Record_Unsafe_unsafeDelete("k")(dyn_S_1)))()
  return Golden_RecordSurgery_Test_logShow(Golden_RecordSurgery_Test_coerced)()
end)()
