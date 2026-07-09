local M = {}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_ForeignSharing_Token_foreign = { token = {} }
M.Golden_ForeignSharing_Test_foreign = {
  same = function(a) return function(b) return rawequal(a, b) end end
}
return M.Effect_Console_foreign.log((function()
  local Golden_ForeignSharing_Token_foreign = M.Golden_ForeignSharing_Token_foreign
  if M.Golden_ForeignSharing_Test_foreign.same(Golden_ForeignSharing_Token_foreign.token)(Golden_ForeignSharing_Token_foreign.token) then
    return "shared"
  else
    return "fresh"
  end
end)())()
