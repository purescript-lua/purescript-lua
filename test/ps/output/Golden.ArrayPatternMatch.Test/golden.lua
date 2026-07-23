local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_ArrayPatternMatch_Test_logShow = function(a_S_2)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_2))
end
local Golden_ArrayPatternMatch_Test_lastOfThree = function(v)
  if 3 == #(v) then return v[3] else return -1 end
end
local Golden_ArrayPatternMatch_Test_firstTwo = function(v)
  if 2 == #(v) then return v[1] + v[2] else return -1 end
end
return (function()
  local _ = Golden_ArrayPatternMatch_Test_logShow(Golden_ArrayPatternMatch_Test_firstTwo({
    [1] = 10,
    [2] = 20
  }))()
  local _ = Golden_ArrayPatternMatch_Test_logShow(Golden_ArrayPatternMatch_Test_firstTwo({
    [1] = 1,
    [2] = 2,
    [3] = 3
  }))()
  local _ = Golden_ArrayPatternMatch_Test_logShow(Golden_ArrayPatternMatch_Test_firstTwo({}))()
  return Golden_ArrayPatternMatch_Test_logShow(Golden_ArrayPatternMatch_Test_lastOfThree({
    [1] = 7,
    [2] = 8,
    [3] = 9
  }))()
end)()
