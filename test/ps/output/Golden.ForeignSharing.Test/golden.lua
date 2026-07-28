local Golden_ForeignSharing_Token_token = {}
return (function(s) return function() print(s) end end)((function()
  if (function(a)
    return function(b) return rawequal(a, b) end
  end)(Golden_ForeignSharing_Token_token)(Golden_ForeignSharing_Token_token) then
    return "shared"
  else
    return "fresh"
  end
end)())()
