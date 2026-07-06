local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      else
        if state == 1 then
          return error(name .. " was needed before it finished initializing")
        else
          state = 1
          val = init()
          state = 2
          return val
        end
      end
    end
  end
end
local M = {}
M.Data_Unit_foreign = { unit = {} }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_RecGroupOrder_Test_store = function(f)
  return { run = f, tag = "ok!" }
end
return (function()
  local Lazy_record_S_0
  local record_S_1
  Lazy_record_S_0 = PSLUA_runtime_lazy("record")(function()
    return M.Golden_RecGroupOrder_Test_store(function()
      return (Lazy_record_S_0(0)).tag
    end)
  end)
  record_S_1 = Lazy_record_S_0(0)
  return M.Effect_Console_foreign.log(record_S_1.run(M.Data_Unit_foreign.unit))
end)()()
