local M = {}
local Record_Unsafe_foreign = {
  unsafeHas = function(l) return function(r) return r[l] ~= nil end end,
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
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_log = function(s) return function() print(s) end end
M.Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end
}
local Golden_RecordSurgery_Test_logShow = function(a_S_0)
  return Effect_Console_log(Data_Show_foreign.showIntImpl(a_S_0))
end
local Golden_RecordSurgery_Test_logShow1 = function(a_S_1)
  return Effect_Console_log((function()
    if a_S_1 then return "true" else return "false" end
  end)())
end
M.Golden_RecordSurgery_Test_replaced = { a = 3 }
M.Golden_RecordSurgery_Test_inserted = { a = 1, b = 2 }
M.Golden_RecordSurgery_Test_deleted = { b = 2 }
return (function()
  local ref_S_0 = { k = 9, n = 1 }
  local dyn_S_0 = ref_S_0
  local _ = Golden_RecordSurgery_Test_logShow(3)()
  local _ = Golden_RecordSurgery_Test_logShow(3)()
  local _ = Golden_RecordSurgery_Test_logShow(2)()
  local _ = Golden_RecordSurgery_Test_logShow(42)()
  local _ = Golden_RecordSurgery_Test_logShow1(true)()
  local _ = Golden_RecordSurgery_Test_logShow1(false)()
  local _ = Golden_RecordSurgery_Test_logShow((Record_Unsafe_foreign.unsafeSet("k")(dyn_S_0.k + 1)(dyn_S_0)).k)()
  local _ = Golden_RecordSurgery_Test_logShow1(Record_Unsafe_foreign.unsafeHas("k")(Record_Unsafe_foreign.unsafeDelete("k")(dyn_S_0)))()
  return Golden_RecordSurgery_Test_logShow(7)()
end)()
