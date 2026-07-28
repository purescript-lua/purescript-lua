local Effect_Console_log = function(s) return function() print(s) end end
local Golden_CharLiterals_Test_show = function(n)
  local code = n:byte()
  if code < 32 or code == 127 then
    if n == "\a" then return "'\\a'" end
    if n == "\b" then return "'\\b'" end
    if n == "\f" then return "'\\f'" end
    if n == "\n" then return "'\\n'" end
    if n == "\r" then return "'\\r'" end
    if n == "\t" then return "'\\t'" end
    if n == "\v" then return "'\\v'" end
    return "'\\" .. tostring(code) .. "'"
  end
  if n == "'" or n == "\\" then return "'\\" .. n .. "'" end
  return "'" .. n .. "'"
end
return (function()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\n"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\t"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\r"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\'"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\\"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("a"))()
  local _ = Effect_Console_log("true")()
  return Effect_Console_log("true")()
end)()
