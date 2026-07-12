local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_ArrayPatternMatch_Test_lastOfThree = function(v)
  if 3 == #(v) then return v[3] else return -1 end
end
M.Golden_ArrayPatternMatch_Test_firstTwo = function(v)
  if 2 == #(v) then return v[1] + v[2] else return -1 end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local v_S_235 = { [1] = 10, [2] = 20 }
    if 2 == #(v_S_235) then return v_S_235[1] + v_S_235[2] else return -1 end
  end)()))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local v_S_242 = { [1] = 1, [2] = 2, [3] = 3 }
    if 2 == #(v_S_242) then return v_S_242[1] + v_S_242[2] else return -1 end
  end)()))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    if 2 == #({}) then return ({})[1] + ({})[2] else return -1 end
  end)()))()
  return Effect_Console_log(Data_Show_showIntImpl((function()
    local v_S_256 = { [1] = 7, [2] = 8, [3] = 9 }
    if 3 == #(v_S_256) then return v_S_256[3] else return -1 end
  end)()))()
end)()
