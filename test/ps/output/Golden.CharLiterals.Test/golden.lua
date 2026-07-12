local Data_Show_foreign = {
  showCharImpl = function(n)
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
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_CharLiterals_Test_show = Data_Show_foreign.showCharImpl
return (function()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\n"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\t"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\r"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\'"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("\\"))()
  local _ = Effect_Console_log(Golden_CharLiterals_Test_show("a"))()
  local _ = Effect_Console_log("true")()
  return Effect_Console_log((function()
    local v_S_111_S_230 = "Data.Ordering∷Ordering.LT" == (function()
      if "\t" < "\n" then
        return "Data.Ordering∷Ordering.LT"
      else
        return "Data.Ordering∷Ordering.GT"
      end
    end)()
    if v_S_111_S_230 then
      return "true"
    elseif false == v_S_111_S_230 then
      return "false"
    else
      return error("No patterns matched")
    end
  end)())()
end)()
