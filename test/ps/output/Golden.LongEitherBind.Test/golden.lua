local Data_Show_foreign = {
  showIntImpl = function(n) return tostring(n) end,
  showStringImpl = function(s)
    -- Mirror PureScript's `show`: wrap in double quotes and escape control
    -- characters, '"' and '\' so the result round-trips to a String literal.
    local out = { "\"" }
    local len = #(s)
    local i = 1
    while i <= len do
      local c = s:sub(i, i)
      local b = c:byte()
      if c == "\"" or c == "\\" then
        out[#(out) + 1] = "\\" .. c
      elseif b == 7 then
        out[#(out) + 1] = "\\a"
      elseif b == 8 then
        out[#(out) + 1] = "\\b"
      elseif b == 12 then
        out[#(out) + 1] = "\\f"
      elseif b == 10 then
        out[#(out) + 1] = "\\n"
      elseif b == 13 then
        out[#(out) + 1] = "\\r"
      elseif b == 9 then
        out[#(out) + 1] = "\\t"
      elseif b == 11 then
        out[#(out) + 1] = "\\v"
      elseif b < 32 or b == 127 then
        -- numeric escape; "\&" guards against a following digit being
        -- swallowed into the escape (e.g. "\27\&5" /= "\275").
        local nxt = s:sub(i + 1, i + 1)
        local gap = nxt >= "0" and nxt <= "9" and "\\&" or ""
        out[#(out) + 1] = "\\" .. tostring(b) .. gap
      else
        out[#(out) + 1] = c
      end
      i = i + 1
    end
    out[#(out) + 1] = "\""
    return table.concat(out)
  end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Either_append_S_w = function(s1_S_331, s2_S_332)
  return s1_S_331 .. s2_S_332
end
local Data_Either_Right = function(value0)
  return { "Data.Either∷Either.Right", value0 }
end
local Golden_LongEitherBind_Test_add_S_w = function(x_S_326, y_S_327)
  return x_S_326 + y_S_327
end
local Golden_LongEitherBind_Test_compute = (function()
  local x150 = (function()
    local _S_tmp1239 = Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(1, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
    local _S_tmp1240 = Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(_S_tmp1239, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
    local _S_tmp1241 = Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(_S_tmp1240, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
    return Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(_S_tmp1241, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
  end)()
  local _S_tmp1242 = Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(x150, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
  local _S_tmp1243 = Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(_S_tmp1242, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
  local _S_tmp1244 = Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(_S_tmp1243, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)
  return Data_Either_Right(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(1, x150), Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(Golden_LongEitherBind_Test_add_S_w(_S_tmp1244, 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1), 1)))
end)()
return (function()
  local _S_cse1238 = Golden_LongEitherBind_Test_compute[2]
  local _S_cse1237 = Golden_LongEitherBind_Test_compute[1]
  return Effect_Console_foreign.log((function()
    if "Data.Either∷Either.Left" == _S_cse1237 then
      return Data_Either_append_S_w("(Left ", Data_Either_append_S_w(Data_Show_foreign.showStringImpl(_S_cse1238), ")"))
    elseif "Data.Either∷Either.Right" == _S_cse1237 then
      return Data_Either_append_S_w("(Right ", Data_Either_append_S_w(Data_Show_foreign.showIntImpl(_S_cse1238), ")"))
    else
      return error("No patterns matched")
    end
  end)())
end)()()
