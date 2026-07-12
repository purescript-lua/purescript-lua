local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_ForeignSharing_Token_foreign = { token = {} }
local Golden_ForeignSharing_Token_token = Golden_ForeignSharing_Token_foreign.token
local Golden_ForeignSharing_Test_foreign = {
  same = function(a) return function(b) return rawequal(a, b) end end
}
return Effect_Console_foreign.log((function()
  if Golden_ForeignSharing_Test_foreign.same(Golden_ForeignSharing_Token_token)(Golden_ForeignSharing_Token_token) then
    return "shared"
  else
    return "fresh"
  end
end)())()
