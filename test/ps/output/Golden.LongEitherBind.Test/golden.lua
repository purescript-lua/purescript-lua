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
local Golden_LongEitherBind_Test_compute = { "Data.Either∷Either.Right", 451 }
return (function()
  local _S_cse0 = Golden_LongEitherBind_Test_compute[2]
  local s = (function()
    if "Data.Either∷Either.Left" == Golden_LongEitherBind_Test_compute[1] then
      return "(Left " .. Data_Show_foreign.showStringImpl(_S_cse0) .. ")"
    else
      return "(Right " .. Data_Show_foreign.showIntImpl(_S_cse0) .. ")"
    end
  end)()
  print(s)
end)()
