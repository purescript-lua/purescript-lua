local Effect_Console_log = function(s) return function() print(s) end end
local Golden_ForeignHeader_Test_foreign = (function()
  local prefix = "tag"
  return { tag = prefix .. "ged" }
end)()
local Golden_ForeignHeader_Test_tag = Golden_ForeignHeader_Test_foreign.tag
return (function()
  local _ = Effect_Console_log(Golden_ForeignHeader_Test_tag)()
  return Effect_Console_log(Golden_ForeignHeader_Test_tag)()
end)()
