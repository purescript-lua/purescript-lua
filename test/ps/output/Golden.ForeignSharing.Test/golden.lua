local M = {}
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Golden_ForeignSharing_Token_foreign = { token = {} }
M.Golden_ForeignSharing_Test_foreign = {
  same = function(a)
      return function(b)
        return rawequal(a, b)
      end
    end
}
M.Golden_ForeignSharing_Test_sharedToken = function()
  return M.Golden_ForeignSharing_Token_foreign.token
end
return M.Effect_Console_foreign.log((function()
  if M.Golden_ForeignSharing_Test_foreign.same(M.Golden_ForeignSharing_Test_sharedToken(0))(M.Golden_ForeignSharing_Test_sharedToken(1)) then
    return "shared"
  else
    return "fresh"
  end
end)())()
