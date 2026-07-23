local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      elseif state == 1 then
        return error(name .. " was needed before it finished initializing")
      else
        state = 1
        val = init()
        state = 2
        return val
      end
    end
  end
end
local Data_Show_foreign = {
  showIntImpl = function(n) return tostring(n) end,
  showArrayImpl = function(f)
    return function(xs)
      local l = #(xs)
      local ss = {}
      for i = 1, l do ss[i] = f(xs[i]) end
      return "[" .. table.concat(ss, ",") .. "]"
    end
  end
}
local Data_Show_showArrayImpl = Data_Show_foreign.showArrayImpl
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Data_Functor_foreign = {
  arrayMap = function(f)
    return function(arr)
      local l = #(arr)
      local result = {}
      for i = 1, l do result[i] = f(arr[i]) end
      return result
    end
  end
}
local Data_Bounded_foreign = {
  -- Lua 5.1 compatibility:
  -- * math.maxinteger/math.mininteger appeared in Lua 5.3; PureScript Int
  --   is a 32-bit integer, so its bounds are spelled out literally.
  -- * "\u{...}" escapes appeared in Lua 5.3 (PUC Lua 5.1 silently reads
  --   "\u" as "u"). A Char is a single byte in pslua, so its bounds are
  --   the byte bounds.
  topChar = "\255",
  bottomChar = "\0"
}
local Data_Bounded_bottomChar = Data_Bounded_foreign.bottomChar
local Data_Bounded_topChar = Data_Bounded_foreign.topChar
local Data_EuclideanRing_foreign = {
  -- math.maxinteger is Lua 5.3+; PureScript Int is 32-bit, hence the
  -- literal bound in intDegree.
  intDegree = function(x) return math.min(math.abs(x), 2147483647) end,
  intDiv = function(x)
    return function(y)
      if y == 0 then return 0 end
      return y > 0 and math.floor(x / y) or -(math.floor(x / -(y)))
    end
  end,
  intMod = function(x)
    return function(y)
      if y == 0 then return 0 end
      local yy = math.abs(y)
      return (x % yy + yy) % yy
    end
  end
}
local Partial_Unsafe_foreign = { _unsafePartial = function(f) return f() end }
local Partial_Unsafe__unsafePartial = Partial_Unsafe_foreign._unsafePartial
local Data_Unfoldable_foreign = {
  unfoldrArrayImpl = function(isNothing)
    return function(fromJust)
      return function(fst)
        return function(snd)
          return function(f)
            return function(b)
              local result = {}
              local value = b
              while true do
                local maybe = f(value)
                if isNothing(maybe) then return result end
                local tuple = fromJust(maybe)
                table.insert(result, fst(tuple))
                value = snd(tuple)
              end
            end
          end
        end
      end
    end
  end
}
local Data_Array_foreign = { length = function(xs) return #(xs) end }
local Data_Enum_foreign = {
  toCharCode = function(c)
    -- pslua compiles a PureScript Char literal as a string of its UTF-8 bytes,
    -- so decode the first code point (JS c.charCodeAt(0)) when the WHOLE
    -- sequence is present. But Data.String.CodeUnits hands this single raw bytes
    -- (it slices a String byte-wise and lets the CodePoints layer reassemble),
    -- so a lone lead/continuation byte must return that byte rather than read a
    -- missing c:byte(2) and crash on nil.
    local n = #(c)
    local b1 = c:byte(1)
    if b1 < 128 then return b1 end
    if b1 < 224 and n >= 2 then return (b1 - 192) * 64 + (c:byte(2) - 128) end
    if b1 < 240 and n >= 3 then
      return (b1 - 224) * 4096 + (c:byte(2) - 128) * 64 + (c:byte(3) - 128)
    end
    if b1 >= 240 and n >= 4 then
      return (b1 - 240) * 262144 + (c:byte(2) - 128) * 4096 + (c:byte(3) - 128) * 64 + (c:byte(4) - 128)
    end
    return b1
  end,
  fromCharCode = function(n)
    -- Encode the code point as UTF-8 (JS String.fromCharCode over 0..65535);
    -- string.char alone errors above 255 and emits a raw byte for 128..255.
    if n < 128 then return string.char(n) end
    if n < 2048 then
      return string.char(192 + math.floor(n / 64), 128 + n % 64)
    end
    if n < 65536 then
      return string.char(224 + math.floor(n / 4096), 128 + math.floor(n / 64) % 64, 128 + n % 64)
    end
    return string.char(240 + math.floor(n / 262144), 128 + math.floor(n / 4096) % 64, 128 + math.floor(n / 64) % 64, 128 + n % 64)
  end
}
local Data_Enum_toCharCode = Data_Enum_foreign.toCharCode
local Data_String_Unsafe_foreign = {
  charAt = function(i)
    return function(s)
      if i >= 0 and i < #(s) then return s:sub(i + 1, i + 1) end
      error("Data.String.Unsafe.charAt: Invalid index.")
    end
  end
}
local Data_String_Unsafe_charAt = Data_String_Unsafe_foreign.charAt
local Data_String_CodeUnits_foreign = {
  -- PureScript indices are 0-based, Lua string positions are 1-based;
  -- the exports below convert between the two. Pattern arguments are
  -- literal strings, hence string.find in plain mode. Index clamping
  -- mirrors the upstream JS implementation (String.prototype.indexOf,
  -- lastIndexOf, slice and substring).
  singleton = function(c) return c end,
  length = function(s) return #(s) end,
  drop = function(n) return function(s) return s:sub(math.max(n, 0) + 1) end end
}
local Data_String_CodeUnits_length = Data_String_CodeUnits_foreign.length
local Data_String_CodePoints_foreign = (function()
  -- In pslua a PureScript String is a Lua byte string holding UTF-8,
  -- so code-point operations decode/encode UTF-8 directly. The PureScript
  -- fallback arguments are written for UTF-16 code units and are wrong
  -- under this representation; every export ignores them.
  --
  -- Lua 5.1: no utf8 library, no bit operators - plain arithmetic only.
  -- Decodes the code point starting at byte position i.
  -- Returns the code point and the position of the next one.
  -- An invalid leading byte is returned as-is (one byte consumed).
  local function decode(s, i)
    local b1 = s:byte(i)
    if b1 < 128 then return b1, i + 1 end
    if b1 >= 194 and b1 <= 223 then
      local b2 = s:byte(i + 1)
      if b2 and b2 >= 128 and b2 <= 191 then
        return (b1 - 192) * 64 + (b2 - 128), i + 2
      end
    elseif b1 >= 224 and b1 <= 239 then
      local b2, b3 = s:byte(i + 1, i + 2)
      if b2 and b2 >= 128 and b2 <= 191 and b3 and b3 >= 128 and b3 <= 191 then
        return (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128), i + 3
      end
    elseif b1 >= 240 and b1 <= 244 then
      local b2, b3, b4 = s:byte(i + 1, i + 3)
      if b2 and b2 >= 128 and b2 <= 191 and b3 and b3 >= 128 and b3 <= 191 and b4 and b4 >= 128 and b4 <= 191 then
        return (b1 - 240) * 262144 + (b2 - 128) * 4096 + (b3 - 128) * 64 + (b4 - 128), i + 4
      end
    end
    return b1, i + 1
  end
  -- Encodes a code point as a UTF-8 byte string.
  local function encode(cp)
    if cp < 128 then return string.char(cp) end
    if cp < 2048 then
      return string.char(192 + math.floor(cp / 64), 128 + cp % 64)
    end
    if cp < 65536 then
      return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
    end
    return string.char(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64, 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
  end
  return {
    _singleton = function(_) return function(cp) return encode(cp) end end,
    _fromCodePointArray = function(_)
      return function(cps)
        local t = {}
        for k = 1, #(cps) do t[k] = encode(cps[k]) end
        return table.concat(t)
      end
    end,
    _toCodePointArray = function(_)
      return function(_)
        return function(s)
          local t, k, i = {}, 0, 1
          while i <= #(s) do
            local cp, j = decode(s, i)
            k = k + 1
            t[k] = cp
            i = j
          end
          return t
        end
      end
    end,
    _codePointAt = function(_)
      return function(just)
        return function(nothing)
          return function(_)
            return function(n)
              return function(s)
                local k, i = 0, 1
                while i <= #(s) do
                  local cp, j = decode(s, i)
                  if k == n then return just(cp) end
                  k = k + 1
                  i = j
                end
                return nothing
              end
            end
          end
        end
      end
    end,
    _take = function(_)
      return function(n)
        return function(s)
          if n < 1 then return "" end
          local k, i = 0, 1
          while i <= #(s) do
            local _, j = decode(s, i)
            k = k + 1
            i = j
            if k == n then break end
          end
          return s:sub(1, i - 1)
        end
      end
    end,
    _unsafeCodePointAt0 = function(_)
      return function(s) local cp = decode(s, 1) return cp end
    end
  }
end)()
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_HeytingAlgebra_heytingAlgebraBoolean
Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      return Data_HeytingAlgebra_heytingAlgebraBoolean.disj(Data_HeytingAlgebra_heytingAlgebraBoolean._not_(a))(b)
    end
  end,
  conj = function(b1_S_1500)
    return function(b2_S_1501) return b1_S_1500 and b2_S_1501 end
  end,
  disj = function(b1_S_1498)
    return function(b2_S_1499) return b1_S_1498 or b2_S_1499 end
  end,
  _not_ = function(b_S_1497) return not(b_S_1497) end
}
local Data_Eq_eqInt = {
  eq = function(r1_S_1493)
    return function(r2_S_1494) return r1_S_1493 == r2_S_1494 end
  end
}
local Data_Show_showInt = { show = Data_Show_showIntImpl }
local Data_Ordering_LT = { "Data.Ordering∷Ordering.LT" }
local Data_Ordering_GT = { "Data.Ordering∷Ordering.GT" }
local Data_Ordering_EQ = { "Data.Ordering∷Ordering.EQ" }
local Data_Ord_ordInt = {
  compare = function(x_S_1477)
    return function(y_S_1478)
      if x_S_1477 < y_S_1478 then
        return Data_Ordering_LT
      elseif x_S_1477 == y_S_1478 then
        return Data_Ordering_EQ
      else
        return Data_Ordering_GT
      end
    end
  end,
  Eq0 = function() return Data_Eq_eqInt end
}
local Data_Ord_greaterThanOrEq_S_w = function(dictOrd, a1, a2)
  return "Data.Ordering∷Ordering.LT" ~= (dictOrd.compare(a1)(a2))[1]
end
local Data_Ord_lessThan_S_w = function(dictOrd, a1, a2)
  return "Data.Ordering∷Ordering.LT" == (dictOrd.compare(a1)(a2))[1]
end
local Data_Ord_lessThanOrEq_S_w = function(dictOrd, a1, a2)
  return "Data.Ordering∷Ordering.GT" ~= (dictOrd.compare(a1)(a2))[1]
end
local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
local Data_Maybe_Just = function(value0)
  return { "Data.Maybe∷Maybe.Just", value0 }
end
local Data_Enum_bottom1 = Data_Bounded_bottomChar
local Data_Enum_top1 = Data_Bounded_topChar
local Data_String_CodePoints_conj = Data_HeytingAlgebra_heytingAlgebraBoolean.conj
local Data_String_CodePoints_fromEnum = Data_Enum_toCharCode
local Data_String_CodePoints_unsafeCodePointAt0 = Data_String_CodePoints_foreign._unsafeCodePointAt0(function( s_S_24 )
  local cu0_S_25 = Data_String_CodePoints_fromEnum(Data_String_Unsafe_charAt(0)(s_S_24))
  if Data_String_CodePoints_conj(Data_String_CodePoints_conj(Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, 55296, cu0_S_25))(Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, cu0_S_25, 56319)))("Data.Ordering∷Ordering.GT" == ((function(  )
    local x_S_1600 = Data_String_CodeUnits_length(s_S_24)
    return function(y_S_1601)
      if x_S_1600 < y_S_1601 then
        return Data_Ordering_LT
      elseif x_S_1600 == y_S_1601 then
        return Data_Ordering_EQ
      else
        return Data_Ordering_GT
      end
    end
  end)()(1))[1]) then
    local cu1_S_27 = Data_String_CodePoints_fromEnum(Data_String_Unsafe_charAt(1)(s_S_24))
    if Data_String_CodePoints_conj(Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, 56320, cu1_S_27))(Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, cu1_S_27, 57343)) then
      return (cu0_S_25 - 55296) * 1024 + (cu1_S_27 - 56320) + 65536
    else
      return cu0_S_25
    end
  else
    return cu0_S_25
  end
end)
local Data_String_CodePoints_fromCharCode = function(x_S_1726)
  return Data_String_CodeUnits_foreign.singleton((function()
    local v_S_60 = (function()
      if Data_HeytingAlgebra_heytingAlgebraBoolean.conj(Data_Ord_greaterThanOrEq_S_w(Data_Ord_ordInt, x_S_1726, Data_Enum_toCharCode(Data_Enum_bottom1)))(Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, x_S_1726, Data_Enum_toCharCode(Data_Enum_top1))) then
        return {
          "Data.Maybe∷Maybe.Just",
          (Data_Enum_foreign.fromCharCode(x_S_1726))
        }
      else
        return Data_Maybe_Nothing
      end
    end)()
    if "Data.Maybe∷Maybe.Just" == v_S_60[1] then
      return v_S_60[2]
    elseif Data_Ord_lessThan_S_w(Data_Ord_ordInt, x_S_1726, Data_Enum_toCharCode(Data_Bounded_bottomChar)) then
      return Data_Bounded_bottomChar
    else
      return Data_Bounded_topChar
    end
  end)())
end
local Data_String_CodePoints_singletonFallback = function(v)
  if Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, v, 65535) then
    return Data_String_CodePoints_fromCharCode(v)
  else
    return Data_String_CodePoints_fromCharCode(Data_EuclideanRing_foreign.intDiv(v - 65536)(1024) + 55296) .. Data_String_CodePoints_fromCharCode(Data_EuclideanRing_foreign.intMod(v - 65536)(1024) + 56320)
  end
end
local Data_String_CodePoints_singleton = Data_String_CodePoints_foreign._singleton(Data_String_CodePoints_singletonFallback)
local Data_String_CodePoints_ordCodePoint = {
  compare = function(x)
    return function(y)
      if x < y then
        return Data_Ordering_LT
      elseif x == y then
        return Data_Ordering_EQ
      else
        return Data_Ordering_GT
      end
    end
  end,
  Eq0 = function()
    return {
      eq = function(x_S_17)
        return function(y_S_18) return x_S_17 == y_S_18 end
      end
    }
  end
}
local Data_String_CodePoints_drop_S_w
local Data_String_CodePoints_uncons = function(s)
  if Data_String_CodeUnits_length(s) == 0 then
    return Data_Maybe_Nothing
  else
    return {
      "Data.Maybe∷Maybe.Just",
      {
        head = Data_String_CodePoints_unsafeCodePointAt0(s),
        tail = Data_String_CodePoints_drop_S_w(1, s)
      }
    }
  end
end
local Data_String_CodePoints_takeFallback_S_w
Data_String_CodePoints_takeFallback_S_w = function(v, v1)
  if Data_Ord_lessThan_S_w(Data_Ord_ordInt, v, 1) then
    return ""
  else
    local v2_S_14 = Data_String_CodePoints_uncons(v1)
    if "Data.Maybe∷Maybe.Just" == v2_S_14[1] then
      return Data_String_CodePoints_singleton(v2_S_14[2].head) .. Data_String_CodePoints_takeFallback_S_w(v - 1, v2_S_14[2].tail)
    else
      return v1
    end
  end
end
local Data_String_CodePoints_takeFallback = function(takeFallback_S_p1)
  return function(takeFallback_S_p2)
    return Data_String_CodePoints_takeFallback_S_w(takeFallback_S_p1, takeFallback_S_p2)
  end
end
local Data_String_CodePoints_take_S_w = function(n, s)
  return Data_String_CodePoints_foreign._take(Data_String_CodePoints_takeFallback)(n)(s)
end
Data_String_CodePoints_drop_S_w = function(n, s)
  return Data_String_CodeUnits_foreign.drop(Data_String_CodeUnits_length(Data_String_CodePoints_take_S_w(n, s)))(s)
end
local Data_String_CodePoints_toCodePointArray = Data_String_CodePoints_foreign._toCodePointArray(function( s_S_7 )
  return Data_Unfoldable_foreign.unfoldrArrayImpl(function(v2_S_1524)
    return "Data.Maybe∷Maybe.Nothing" == v2_S_1524[1]
  end)(Partial_Unsafe__unsafePartial(function()
    return function(v_S_1574)
      if "Data.Maybe∷Maybe.Just" == v_S_1574[1] then
        return v_S_1574[2]
      else
        return error("No patterns matched")
      end
    end
  end))(function(v_S_1522) return v_S_1522[1] end)(function(v_S_1523)
    return v_S_1523[2]
  end)(function(s_S_8)
    local v1_S_1577 = Data_String_CodePoints_uncons(s_S_8)
    if "Data.Maybe∷Maybe.Just" == v1_S_1577[1] then
      return {
        "Data.Maybe∷Maybe.Just",
        { v1_S_1577[2].head, v1_S_1577[2].tail }
      }
    else
      return Data_Maybe_Nothing
    end
  end)(s_S_7)
end)(Data_String_CodePoints_unsafeCodePointAt0)
local Data_String_CodePoints_codePointAtFallback_S_w = function(n, s)
  while true do
    local v = Data_String_CodePoints_uncons(s)
    if "Data.Maybe∷Maybe.Just" == v[1] then
      if n == 0 then
        return { "Data.Maybe∷Maybe.Just", v[2].head }
      else
        n, s = n - 1, v[2].tail
      end
    else
      return Data_Maybe_Nothing
    end
  end
end
local Data_String_CodePoints_codePointAtFallback = function( codePointAtFallback_S_p1 )
  return function(codePointAtFallback_S_p2)
    return Data_String_CodePoints_codePointAtFallback_S_w(codePointAtFallback_S_p1, codePointAtFallback_S_p2)
  end
end
local Data_String_CodePoints_codePointAt_S_w = function(v, v1)
  if Data_Ord_lessThan_S_w(Data_Ord_ordInt, v, 0) then
    return Data_Maybe_Nothing
  elseif 0 == v then
    if "" == v1 then
      return Data_Maybe_Nothing
    else
      return {
        "Data.Maybe∷Maybe.Just",
        (Data_String_CodePoints_unsafeCodePointAt0(v1))
      }
    end
  else
    return Data_String_CodePoints_foreign._codePointAt(Data_String_CodePoints_codePointAtFallback)(Data_Maybe_Just)(Data_Maybe_Nothing)(Data_String_CodePoints_unsafeCodePointAt0)(v)(v1)
  end
end
local Data_String_CodePoints_Lazy_enumCodePoint
local Data_String_CodePoints_boundedEnumCodePoint = {
  cardinality = 1114112,
  fromEnum = function(v) return v end,
  toEnum = function(n0)
    if Data_String_CodePoints_conj(Data_Ord_greaterThanOrEq_S_w(Data_Ord_ordInt, n0, 0))(Data_Ord_lessThanOrEq_S_w(Data_Ord_ordInt, n0, 1114111)) then
      return { "Data.Maybe∷Maybe.Just", n0 }
    else
      return Data_Maybe_Nothing
    end
  end,
  Bounded0 = function()
    return {
      bottom = 0,
      top = 1114111,
      Ord0 = function() return Data_String_CodePoints_ordCodePoint end
    }
  end,
  Enum1 = function() return Data_String_CodePoints_Lazy_enumCodePoint(0) end
}
Data_String_CodePoints_Lazy_enumCodePoint = PSLUA_runtime_lazy("enumCodePoint")(function(  )
  return {
    succ = function(a_S_1560)
      return Data_String_CodePoints_boundedEnumCodePoint.toEnum(Data_String_CodePoints_boundedEnumCodePoint.fromEnum(a_S_1560) + 1)
    end,
    pred = function(a_S_1568)
      return Data_String_CodePoints_boundedEnumCodePoint.toEnum(Data_String_CodePoints_boundedEnumCodePoint.fromEnum(a_S_1568) - 1)
    end,
    Ord0 = function() return Data_String_CodePoints_ordCodePoint end
  }
end)
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
end
local Golden_StringCodePoints_Test_fromEnum = Data_String_CodePoints_boundedEnumCodePoint.fromEnum
local Golden_StringCodePoints_Test_showArray = {
  show = Data_Show_showArrayImpl(Data_Show_showIntImpl)
}
local Golden_StringCodePoints_Test_logShow2 = function(logShow_S_p2_S_1697)
  return Effect_Console_logShow_S_w({
    show = function(v_S_1691)
      if "Data.Maybe∷Maybe.Just" == v_S_1691[1] then
        return "(Just " .. Data_Show_showIntImpl(v_S_1691[2]) .. ")"
      else
        return "Nothing"
      end
    end
  }, logShow_S_p2_S_1697)
end
local Golden_StringCodePoints_Test_cp = function(x_S_1689)
  return Partial_Unsafe__unsafePartial(function()
    return function(v_S_1532)
      if "Data.Maybe∷Maybe.Just" == v_S_1532[1] then
        return v_S_1532[2]
      else
        return error("No patterns matched")
      end
    end
  end)(Data_String_CodePoints_boundedEnumCodePoint.toEnum(x_S_1689))
end
local Golden_StringCodePoints_Test_codes = function(x_S_1686)
  return Data_Functor_foreign.arrayMap(Golden_StringCodePoints_Test_fromEnum)(Data_String_CodePoints_toCodePointArray(x_S_1686))
end
return (function()
  local _ = Effect_Console_logShow_S_w(Golden_StringCodePoints_Test_showArray, Golden_StringCodePoints_Test_codes("aéЯ𝐀z"))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Data_Array_foreign.length(Data_String_CodePoints_toCodePointArray("aéЯ𝐀z")))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Data_String_CodeUnits_length("aéЯ𝐀z"))()
  local _ = Effect_Console_logShow_S_w(Golden_StringCodePoints_Test_showArray, Golden_StringCodePoints_Test_codes(Data_String_CodePoints_take_S_w(2, "aéЯ𝐀z")))()
  local _ = Effect_Console_logShow_S_w(Golden_StringCodePoints_Test_showArray, Golden_StringCodePoints_Test_codes(Data_String_CodePoints_drop_S_w(2, "aéЯ𝐀z")))()
  local _ = Golden_StringCodePoints_Test_logShow2((function()
    local v1_S_1748 = Data_String_CodePoints_codePointAt_S_w(0, "aéЯ𝐀z")
    if "Data.Maybe∷Maybe.Just" == v1_S_1748[1] then
      return {
        "Data.Maybe∷Maybe.Just",
        (Golden_StringCodePoints_Test_fromEnum(v1_S_1748[2]))
      }
    else
      return Data_Maybe_Nothing
    end
  end)())()
  local _ = Golden_StringCodePoints_Test_logShow2((function()
    local v1_S_1750 = Data_String_CodePoints_codePointAt_S_w(3, "aéЯ𝐀z")
    if "Data.Maybe∷Maybe.Just" == v1_S_1750[1] then
      return {
        "Data.Maybe∷Maybe.Just",
        (Golden_StringCodePoints_Test_fromEnum(v1_S_1750[2]))
      }
    else
      return Data_Maybe_Nothing
    end
  end)())()
  local _ = Golden_StringCodePoints_Test_logShow2((function()
    local v1_S_1752 = Data_String_CodePoints_codePointAt_S_w(5, "aéЯ𝐀z")
    if "Data.Maybe∷Maybe.Just" == v1_S_1752[1] then
      return {
        "Data.Maybe∷Maybe.Just",
        (Golden_StringCodePoints_Test_fromEnum(v1_S_1752[2]))
      }
    else
      return Data_Maybe_Nothing
    end
  end)())()
  local _ = Golden_StringCodePoints_Test_logShow2((function()
    local v1_S_1757 = Data_String_CodePoints_uncons("aéЯ𝐀z")
    if "Data.Maybe∷Maybe.Just" == v1_S_1757[1] then
      return {
        "Data.Maybe∷Maybe.Just",
        (Golden_StringCodePoints_Test_fromEnum(v1_S_1757[2].head))
      }
    else
      return Data_Maybe_Nothing
    end
  end)())()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_1680)
      if "Data.Maybe∷Maybe.Just" == v_S_1680[1] then
        return "(Just " .. Data_Show_showArrayImpl(Data_Show_showIntImpl)(v_S_1680[2]) .. ")"
      else
        return "Nothing"
      end
    end
  }, (function()
    local v1_S_1766 = Data_String_CodePoints_uncons("aéЯ𝐀z")
    if "Data.Maybe∷Maybe.Just" == v1_S_1766[1] then
      return {
        "Data.Maybe∷Maybe.Just",
        (Golden_StringCodePoints_Test_codes(v1_S_1766[2].tail))
      }
    else
      return Data_Maybe_Nothing
    end
  end)())()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_1236)
      if v_S_1236 then return "true" else return "false" end
    end
  }, Data_String_CodePoints_foreign._fromCodePointArray(Data_String_CodePoints_singletonFallback)(Data_String_CodePoints_toCodePointArray("aéЯ𝐀z")) == "aéЯ𝐀z")()
  return Effect_Console_logShow_S_w(Golden_StringCodePoints_Test_showArray, Golden_StringCodePoints_Test_codes(Data_String_CodePoints_singleton(Golden_StringCodePoints_Test_cp(119808))))()
end)()
