local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      elseif state == 1 then
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
local M = {}
local Data_Unit_unit = {}
M.Golden_RecGroupOrder_Test_store = function(f)
  return { run = f, tag = "ok!" }
end
return (function()
  local Lazy_record_S_0
  local record_S_0
  Lazy_record_S_0 = PSLUA_runtime_lazy("record")(function()
    return { run = function() return (Lazy_record_S_0(0)).tag end, tag = "ok!" }
  end)
  record_S_0 = Lazy_record_S_0(0)
  local s = record_S_0.run(Data_Unit_unit)
  print(s)
end)()
