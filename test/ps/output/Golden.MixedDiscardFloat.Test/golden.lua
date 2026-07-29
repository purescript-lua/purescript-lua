local M = {}
M.Data_Unit_unit = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Control_Monad_ST_Internal_foreign = {
  map_ = function(f)
    return function(a) return function() return f(a()) end end
  end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end,
  new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  write = function(a)
    return function(ref) return function() ref.value = a return a end end
  end
}
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_MixedDiscardFloat_Test_stCount = Control_Monad_ST_Internal_foreign.run(function(  )
  local r = 1
  r = 2
  return r
end)
return (function()
  local _ = Effect_Console_log("st:")()
  return Effect_Console_log(Data_Show_foreign.showIntImpl(Golden_MixedDiscardFloat_Test_stCount))()
end)()
