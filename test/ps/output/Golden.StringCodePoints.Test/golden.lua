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
local M = {}
M.Data_HeytingAlgebra_foreign = {
  boolConj = function(b1) return function(b2) return b1 and b2 end end,
  boolDisj = function(b1) return function(b2) return b1 or b2 end end,
  boolNot = function(b) return not(b) end
}
M.Data_Eq_foreign = (function()
  local refEq = function(r1) return function(r2) return r1 == r2 end end
  return { eqIntImpl = refEq, eqCharImpl = refEq, eqStringImpl = refEq }
end)()
M.Data_Semigroup_foreign = {
  concatString = function(s1) return function(s2) return s1 .. s2 end end
}
M.Data_Show_foreign = {
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
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end,
  intMul = function(x) return function(y) return x * y end end
}
M.Data_Ring_foreign = {
  intSub = function(x) return function(y) return x - y end end
}
M.Data_Ord_foreign = (function()
  local unsafeCoerceImpl = function(lt)
    return function(eq)
      return function(gt)
        return function(x)
          return function(y)
            if x < y then
              return lt
            elseif x == y then
              return eq
            else
              return gt
            end
          end
        end
      end
    end
  end
  return { ordIntImpl = unsafeCoerceImpl, ordCharImpl = unsafeCoerceImpl }
end)()
M.Data_Functor_foreign = {
  arrayMap = function(f)
    return function(arr)
      local l = #(arr)
      local result = {}
      for i = 1, l do result[i] = f(arr[i]) end
      return result
    end
  end
}
M.Data_Bounded_foreign = {
  -- Lua 5.1 compatibility:
  -- * math.maxinteger/math.mininteger appeared in Lua 5.3; PureScript Int
  --   is a 32-bit integer, so its bounds are spelled out literally.
  -- * "\u{...}" escapes appeared in Lua 5.3 (PUC Lua 5.1 silently reads
  --   "\u" as "u"). A Char is a single byte in pslua, so its bounds are
  --   the byte bounds.
  topChar = "\255",
  bottomChar = "\0"
}
M.Data_EuclideanRing_foreign = {
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
M.Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
M.Partial_Unsafe_foreign = { _unsafePartial = function(f) return f() end }
M.Data_Unfoldable_foreign = {
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
M.Data_Array_foreign = { length = function(xs) return #(xs) end }
M.Data_Enum_foreign = {
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
M.Data_String_Unsafe_foreign = {
  charAt = function(i)
    return function(s)
      if i >= 0 and i < #(s) then return s:sub(i + 1, i + 1) end
      error("Data.String.Unsafe.charAt: Invalid index.")
    end
  end
}
M.Data_String_CodeUnits_foreign = {
  -- PureScript indices are 0-based, Lua string positions are 1-based;
  -- the exports below convert between the two. Pattern arguments are
  -- literal strings, hence string.find in plain mode. Index clamping
  -- mirrors the upstream JS implementation (String.prototype.indexOf,
  -- lastIndexOf, slice and substring).
  singleton = function(c) return c end,
  length = function(s) return #(s) end,
  drop = function(n) return function(s) return s:sub(math.max(n, 0) + 1) end end
}
M.Data_String_CodePoints_foreign = (function()
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
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Control_Semigroupoid_semigroupoidFn = {
  compose = function(f)
    return function(g) return function(x) return f(g(x)) end end
  end
}
M.Control_Semigroupoid_compose = function(dict) return dict.compose end
M.Data_HeytingAlgebra_heytingAlgebraBoolean = {
  ff = false,
  tt = true,
  implies = function(a)
    return function(b)
      return M.Data_HeytingAlgebra_heytingAlgebraBoolean.disj(M.Data_HeytingAlgebra_heytingAlgebraBoolean._not_(a))(b)
    end
  end,
  conj = M.Data_HeytingAlgebra_foreign.boolConj,
  disj = M.Data_HeytingAlgebra_foreign.boolDisj,
  _not_ = M.Data_HeytingAlgebra_foreign.boolNot
}
M.Data_HeytingAlgebra_conj = function(dict) return dict.conj end
M.Data_Eq_eqInt = { eq = M.Data_Eq_foreign.eqIntImpl }
M.Data_Eq_eq = function(dict) return dict.eq end
M.Data_Semigroup_semigroupString = {
  append = M.Data_Semigroup_foreign.concatString
}
M.Data_Semigroup_append = function(dict) return dict.append end
M.Data_Show_showInt = { show = M.Data_Show_foreign.showIntImpl }
M.Data_Show_show = function(dict) return dict.show end
M.Data_Ordering_LT = { ["$ctor"] = "Data.Ordering∷Ordering.LT" }
M.Data_Ordering_GT = { ["$ctor"] = "Data.Ordering∷Ordering.GT" }
M.Data_Ordering_EQ = { ["$ctor"] = "Data.Ordering∷Ordering.EQ" }
M.Data_Semiring_semiringInt = {
  add = M.Data_Semiring_foreign.intAdd,
  zero = 0,
  mul = M.Data_Semiring_foreign.intMul,
  one = 1
}
M.Data_Semiring_add = function(dict) return dict.add end
M.Data_Ring_sub = function(dict) return dict.sub end
M.Data_Ring_ringInt = {
  sub = M.Data_Ring_foreign.intSub,
  Semiring0 = function() return M.Data_Semiring_semiringInt end
}
M.Data_Ord_ordInt = {
  compare = M.Data_Ord_foreign.ordIntImpl(M.Data_Ordering_LT)(M.Data_Ordering_EQ)(M.Data_Ordering_GT),
  Eq0 = function() return M.Data_Eq_eqInt end
}
M.Data_Ord_ordChar = {
  compare = M.Data_Ord_foreign.ordCharImpl(M.Data_Ordering_LT)(M.Data_Ordering_EQ)(M.Data_Ordering_GT),
  Eq0 = function() return { eq = M.Data_Eq_foreign.eqCharImpl } end
}
M.Data_Ord_compare = function(dict) return dict.compare end
M.Data_Ord_greaterThanOrEq_S_w = function(dictOrd, a1, a2)
  if "Data.Ordering∷Ordering.LT" == (M.Data_Ord_compare(dictOrd)(a1)(a2))["$ctor"] then
    return false
  else
    return true
  end
end
M.Data_Ord_lessThan_S_w = function(dictOrd, a1, a2)
  if "Data.Ordering∷Ordering.LT" == (M.Data_Ord_compare(dictOrd)(a1)(a2))["$ctor"] then
    return true
  else
    return false
  end
end
M.Data_Ord_lessThanOrEq_S_w = function(dictOrd, a1, a2)
  if "Data.Ordering∷Ordering.GT" == (M.Data_Ord_compare(dictOrd)(a1)(a2))["$ctor"] then
    return false
  else
    return true
  end
end
M.Data_Functor_map = function(dict) return dict.map end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Bounded_top = function(dict) return dict.top end
M.Data_Bounded_boundedChar = {
  top = M.Data_Bounded_foreign.topChar,
  bottom = M.Data_Bounded_foreign.bottomChar,
  Ord0 = function() return M.Data_Ord_ordChar end
}
M.Data_Bounded_bottom = function(dict) return dict.bottom end
M.Data_EuclideanRing_euclideanRingInt = {
  degree = M.Data_EuclideanRing_foreign.intDegree,
  div = M.Data_EuclideanRing_foreign.intDiv,
  mod = M.Data_EuclideanRing_foreign.intMod,
  CommutativeRing0 = function()
    return { Ring0 = function() return M.Data_Ring_ringInt end }
  end
}
M.Data_Maybe_append = M.Data_Semigroup_append(M.Data_Semigroup_semigroupString)
M.Data_Maybe_Nothing = { ["$ctor"] = "Data.Maybe∷Maybe.Nothing" }
M.Data_Maybe_Just = function(value0)
  return { ["$ctor"] = "Data.Maybe∷Maybe.Just", value0 = value0 }
end
M.Data_Maybe_showMaybe = function(dictShow)
  return {
    show = function(v)
      if "Data.Maybe∷Maybe.Just" == v["$ctor"] then
        return M.Data_Maybe_append("(Just ")(M.Data_Maybe_append(M.Data_Show_show(dictShow)(v.value0))(")"))
      elseif "Data.Maybe∷Maybe.Nothing" == v["$ctor"] then
        return "Nothing"
      else
        return error("No patterns matched")
      end
    end
  }
end
M.Data_Maybe_functorMaybe = {
  map = function(v)
    return function(v1)
      if "Data.Maybe∷Maybe.Just" == v1["$ctor"] then
        return M.Data_Maybe_Just(v(v1.value0))
      else
        return M.Data_Maybe_Nothing
      end
    end
  end
}
M.Data_Maybe_fromJust = function()
  return function(v)
    if "Data.Maybe∷Maybe.Just" == v["$ctor"] then
      return v.value0
    else
      return error("No patterns matched")
    end
  end
end
M.Effect_monadEffect = {
  Applicative0 = function() return M.Effect_applicativeEffect end,
  Bind1 = function() return M.Effect_bindEffect end
}
M.Effect_bindEffect = {
  bind = M.Effect_foreign.bindE,
  Apply0 = function() return M.Effect_Lazy_applyEffect(0) end
}
M.Effect_applicativeEffect = {
  pure = M.Effect_foreign.pureE,
  Apply0 = function() return M.Effect_Lazy_applyEffect(0) end
}
M.Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_997)
      return function(a_S_998)
        return (M.Effect_applicativeEffect.Apply0()).apply(M.Control_Applicative_pure(M.Effect_applicativeEffect)(f_S_997))(a_S_998)
      end
    end
  }
end)
M.Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_1317 = M.Control_Bind_bind(M.Effect_monadEffect.Bind1())
      return function(f_S_1318)
        return function(a_S_1319)
          return bind_S_1317(f_S_1318)(function(fPrime_S_1320)
            return bind_S_1317(a_S_1319)(function(aPrime_S_1321)
              return M.Control_Applicative_pure(M.Effect_monadEffect.Applicative0())(fPrime_S_1320(aPrime_S_1321))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return M.Effect_Lazy_functorEffect(0) end
  }
end)
M.Data_Enum_sub = M.Data_Ring_sub(M.Data_Ring_ringInt)
M.Data_Enum_bottom1 = M.Data_Bounded_bottom(M.Data_Bounded_boundedChar)
M.Data_Enum_top1 = M.Data_Bounded_top(M.Data_Bounded_boundedChar)
M.Data_Enum_toEnum = function(dict) return dict.toEnum end
M.Data_Enum_fromEnum = function(dict) return dict.fromEnum end
M.Data_Enum_defaultSucc = function(toEnumPrime)
  return function(fromEnumPrime)
    return function(a)
      return toEnumPrime(M.Data_Semiring_add(M.Data_Semiring_semiringInt)(fromEnumPrime(a))(1))
    end
  end
end
M.Data_Enum_defaultPred = function(toEnumPrime)
  return function(fromEnumPrime)
    return function(a)
      return toEnumPrime(M.Data_Enum_sub(fromEnumPrime(a))(1))
    end
  end
end
M.Data_Enum_charToEnum = function(v)
  if M.Data_HeytingAlgebra_conj(M.Data_HeytingAlgebra_heytingAlgebraBoolean)(M.Data_Ord_greaterThanOrEq_S_w(M.Data_Ord_ordInt, v, M.Data_Enum_foreign.toCharCode(M.Data_Enum_bottom1)))(M.Data_Ord_lessThanOrEq_S_w(M.Data_Ord_ordInt, v, M.Data_Enum_foreign.toCharCode(M.Data_Enum_top1))) then
    return M.Data_Maybe_Just(M.Data_Enum_foreign.fromCharCode(v))
  else
    return M.Data_Maybe_Nothing
  end
end
M.Data_Enum_boundedEnumChar = {
  cardinality = M.Data_Enum_sub(M.Data_Enum_foreign.toCharCode(M.Data_Enum_top1))(M.Data_Enum_foreign.toCharCode(M.Data_Enum_bottom1)),
  toEnum = M.Data_Enum_charToEnum,
  fromEnum = M.Data_Enum_foreign.toCharCode,
  Bounded0 = function() return M.Data_Bounded_boundedChar end,
  Enum1 = function()
    return {
      succ = M.Data_Enum_defaultSucc(M.Data_Enum_charToEnum)(M.Data_Enum_foreign.toCharCode),
      pred = M.Data_Enum_defaultPred(M.Data_Enum_charToEnum)(M.Data_Enum_foreign.toCharCode),
      Ord0 = function() return M.Data_Ord_ordChar end
    }
  end
}
M.Data_String_CodePoints_add = M.Data_Semiring_add(M.Data_Semiring_semiringInt)
M.Data_String_CodePoints_sub = M.Data_Ring_sub(M.Data_Ring_ringInt)
M.Data_String_CodePoints_append = M.Data_Semigroup_append(M.Data_Semigroup_semigroupString)
M.Data_String_CodePoints_conj = M.Data_HeytingAlgebra_conj(M.Data_HeytingAlgebra_heytingAlgebraBoolean)
M.Data_String_CodePoints_lessThanOrEq = function(lessThanOrEq_S_p2_S_1337)
  return function(lessThanOrEq_S_p3_S_1338)
    return M.Data_Ord_lessThanOrEq_S_w(M.Data_Ord_ordInt, lessThanOrEq_S_p2_S_1337, lessThanOrEq_S_p3_S_1338)
  end
end
M.Data_String_CodePoints_fromEnum = M.Data_Enum_fromEnum(M.Data_Enum_boundedEnumChar)
M.Data_String_CodePoints_compose = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)
M.Data_String_CodePoints_eq = M.Data_Eq_eq(M.Data_Eq_eqInt)
M.Data_String_CodePoints_lessThan = function(lessThan_S_p2_S_1340)
  return function(lessThan_S_p3_S_1341)
    return M.Data_Ord_lessThan_S_w(M.Data_Ord_ordInt, lessThan_S_p2_S_1340, lessThan_S_p3_S_1341)
  end
end
M.Data_String_CodePoints_unsafeCodePointAt0 = M.Data_String_CodePoints_foreign._unsafeCodePointAt0(function( s_S_27 )
  local cu0_S_28 = M.Data_String_CodePoints_fromEnum(M.Data_String_Unsafe_foreign.charAt(0)(s_S_27))
  if M.Data_String_CodePoints_conj(M.Data_String_CodePoints_conj(M.Data_String_CodePoints_lessThanOrEq(55296)(cu0_S_28))(M.Data_String_CodePoints_lessThanOrEq(cu0_S_28)(56319)))((function(  )
    if "Data.Ordering∷Ordering.GT" == (M.Data_Ord_compare(M.Data_Ord_ordInt)(M.Data_String_CodeUnits_foreign.length(s_S_27))(1))["$ctor"] then
      return true
    else
      return false
    end
  end)()) then
    local cu1_S_30 = M.Data_String_CodePoints_fromEnum(M.Data_String_Unsafe_foreign.charAt(1)(s_S_27))
    if M.Data_String_CodePoints_conj(M.Data_String_CodePoints_lessThanOrEq(56320)(cu1_S_30))(M.Data_String_CodePoints_lessThanOrEq(cu1_S_30)(57343)) then
      return M.Data_String_CodePoints_add(M.Data_String_CodePoints_add(M.Data_Semiring_semiringInt.mul(M.Data_String_CodePoints_sub(cu0_S_28)(55296))(1024))(M.Data_String_CodePoints_sub(cu1_S_30)(56320)))(65536)
    else
      return cu0_S_28
    end
  else
    return cu0_S_28
  end
end)
M.Data_String_CodePoints_fromCharCode = M.Data_String_CodePoints_compose(M.Data_String_CodeUnits_foreign.singleton)(function( x_S_62 )
  local v_S_63 = M.Data_Enum_toEnum(M.Data_Enum_boundedEnumChar)(x_S_62)
  if "Data.Maybe∷Maybe.Just" == v_S_63["$ctor"] then
    return v_S_63.value0
  elseif "Data.Maybe∷Maybe.Nothing" == v_S_63["$ctor"] then
    if M.Data_Ord_lessThan_S_w(M.Data_Ord_ordInt, x_S_62, M.Data_Enum_fromEnum(M.Data_Enum_boundedEnumChar)(M.Data_Bounded_bottom(M.Data_Enum_boundedEnumChar.Bounded0()))) then
      return M.Data_Bounded_bottom(M.Data_Bounded_boundedChar)
    else
      return M.Data_Bounded_top(M.Data_Bounded_boundedChar)
    end
  else
    return error("No patterns matched")
  end
end)
M.Data_String_CodePoints_singletonFallback = function(v)
  if M.Data_String_CodePoints_lessThanOrEq(v)(65535) then
    return M.Data_String_CodePoints_fromCharCode(v)
  else
    return M.Data_String_CodePoints_append(M.Data_String_CodePoints_fromCharCode(M.Data_String_CodePoints_add(M.Data_EuclideanRing_euclideanRingInt.div(M.Data_String_CodePoints_sub(v)(65536))(1024))(55296)))(M.Data_String_CodePoints_fromCharCode(M.Data_String_CodePoints_add(M.Data_EuclideanRing_euclideanRingInt.mod(M.Data_String_CodePoints_sub(v)(65536))(1024))(56320)))
  end
end
M.Data_String_CodePoints_singleton = M.Data_String_CodePoints_foreign._singleton(M.Data_String_CodePoints_singletonFallback)
M.Data_String_CodePoints_ordCodePoint = {
  compare = function(x)
    return function(y) return M.Data_Ord_compare(M.Data_Ord_ordInt)(x)(y) end
  end,
  Eq0 = function()
    return {
      eq = function(x_S_20)
        return function(y_S_21)
          return M.Data_String_CodePoints_eq(x_S_20)(y_S_21)
        end
      end
    }
  end
}
M.Data_String_CodePoints_uncons = function(s)
  if M.Data_String_CodePoints_eq(M.Data_String_CodeUnits_foreign.length(s))(0) then
    return M.Data_Maybe_Nothing
  else
    return M.Data_Maybe_Just({
      head = M.Data_String_CodePoints_unsafeCodePointAt0(s),
      tail = M.Data_String_CodePoints_drop_S_w(1, s)
    })
  end
end
M.Data_String_CodePoints_takeFallback_S_w = function(v, v1)
  if M.Data_String_CodePoints_lessThan(v)(1) then
    return ""
  else
    local v2_S_17 = M.Data_String_CodePoints_uncons(v1)
    if "Data.Maybe∷Maybe.Just" == v2_S_17["$ctor"] then
      return M.Data_String_CodePoints_append(M.Data_String_CodePoints_singleton(v2_S_17.value0.head))(M.Data_String_CodePoints_takeFallback_S_w(M.Data_String_CodePoints_sub(v)(1), v2_S_17.value0.tail))
    else
      return v1
    end
  end
end
M.Data_String_CodePoints_takeFallback = function(takeFallback_S_p1)
  return function(takeFallback_S_p2)
    return M.Data_String_CodePoints_takeFallback_S_w(takeFallback_S_p1, takeFallback_S_p2)
  end
end
M.Data_String_CodePoints_take_S_w = function(n, s)
  return M.Data_String_CodePoints_foreign._take(M.Data_String_CodePoints_takeFallback)(n)(s)
end
M.Data_String_CodePoints_drop_S_w = function(n, s)
  return M.Data_String_CodeUnits_foreign.drop(M.Data_String_CodeUnits_foreign.length(M.Data_String_CodePoints_take_S_w(n, s)))(s)
end
M.Data_String_CodePoints_toCodePointArray = M.Data_String_CodePoints_foreign._toCodePointArray(function( s_S_10 )
  return M.Data_Unfoldable_foreign.unfoldrArrayImpl(function(v2_S_1313_S_1335)
    if "Data.Maybe∷Maybe.Nothing" == v2_S_1313_S_1335["$ctor"] then
      return true
    elseif "Data.Maybe∷Maybe.Just" == v2_S_1313_S_1335["$ctor"] then
      return false
    else
      return error("No patterns matched")
    end
  end)(M.Partial_Unsafe_foreign._unsafePartial(function()
    return M.Data_Maybe_fromJust()
  end))(function(v_S_1333) return v_S_1333.value0 end)(function(v_S_1334)
    return v_S_1334.value1
  end)(function(s_S_11)
    return M.Data_Functor_map(M.Data_Maybe_functorMaybe)(function(v_S_12)
      return (function(value0)
        return function(value1) return { value0 = value0, value1 = value1 } end
      end)(v_S_12.head)(v_S_12.tail)
    end)(M.Data_String_CodePoints_uncons(s_S_11))
  end)(s_S_10)
end)(M.Data_String_CodePoints_unsafeCodePointAt0)
M.Data_String_CodePoints_codePointAtFallback_S_w = function(n, s)
  while true do
    local v = M.Data_String_CodePoints_uncons(s)
    if "Data.Maybe∷Maybe.Just" == v["$ctor"] then
      if M.Data_String_CodePoints_eq(n)(0) then
        return M.Data_Maybe_Just(v.value0.head)
      else
        n, s = M.Data_String_CodePoints_sub(n)(1), v.value0.tail
      end
    else
      return M.Data_Maybe_Nothing
    end
  end
end
M.Data_String_CodePoints_codePointAtFallback = function( codePointAtFallback_S_p1 )
  return function(codePointAtFallback_S_p2)
    return M.Data_String_CodePoints_codePointAtFallback_S_w(codePointAtFallback_S_p1, codePointAtFallback_S_p2)
  end
end
M.Data_String_CodePoints_codePointAt_S_w = function(v, v1)
  if M.Data_String_CodePoints_lessThan(v)(0) then
    return M.Data_Maybe_Nothing
  elseif 0 == v then
    if "" == v1 then
      return M.Data_Maybe_Nothing
    elseif 0 == v then
      return M.Data_Maybe_Just(M.Data_String_CodePoints_unsafeCodePointAt0(v1))
    else
      return M.Data_String_CodePoints_foreign._codePointAt(M.Data_String_CodePoints_codePointAtFallback)(M.Data_Maybe_Just)(M.Data_Maybe_Nothing)(M.Data_String_CodePoints_unsafeCodePointAt0)(v)(v1)
    end
  elseif 0 == v then
    return M.Data_Maybe_Just(M.Data_String_CodePoints_unsafeCodePointAt0(v1))
  else
    return M.Data_String_CodePoints_foreign._codePointAt(M.Data_String_CodePoints_codePointAtFallback)(M.Data_Maybe_Just)(M.Data_Maybe_Nothing)(M.Data_String_CodePoints_unsafeCodePointAt0)(v)(v1)
  end
end
M.Data_String_CodePoints_boundedEnumCodePoint = {
  cardinality = M.Data_String_CodePoints_add(1114111)(1),
  fromEnum = function(v) return v end,
  toEnum = function(n0)
    if M.Data_String_CodePoints_conj(M.Data_Ord_greaterThanOrEq_S_w(M.Data_Ord_ordInt, n0, 0))(M.Data_String_CodePoints_lessThanOrEq(n0)(1114111)) then
      return M.Data_Maybe_Just(n0)
    else
      return M.Data_Maybe_Nothing
    end
  end,
  Bounded0 = function()
    return {
      bottom = 0,
      top = 1114111,
      Ord0 = function() return M.Data_String_CodePoints_ordCodePoint end
    }
  end,
  Enum1 = function() return M.Data_String_CodePoints_Lazy_enumCodePoint(0) end
}
M.Data_String_CodePoints_Lazy_enumCodePoint = PSLUA_runtime_lazy("enumCodePoint")(function(  )
  return {
    succ = M.Data_Enum_defaultSucc(M.Data_Enum_toEnum(M.Data_String_CodePoints_boundedEnumCodePoint))(M.Data_Enum_fromEnum(M.Data_String_CodePoints_boundedEnumCodePoint)),
    pred = M.Data_Enum_defaultPred(M.Data_Enum_toEnum(M.Data_String_CodePoints_boundedEnumCodePoint))(M.Data_Enum_fromEnum(M.Data_String_CodePoints_boundedEnumCodePoint)),
    Ord0 = function() return M.Data_String_CodePoints_ordCodePoint end
  }
end)
M.Effect_Console_logShow_S_w = function(dictShow, a)
  return M.Effect_Console_foreign.log(M.Data_Show_show(dictShow)(a))
end
M.Effect_Console_logShow = function(logShow_S_p1)
  return function(logShow_S_p2)
    return M.Effect_Console_logShow_S_w(logShow_S_p1, logShow_S_p2)
  end
end
M.Golden_StringCodePoints_Test_compose = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)
M.Golden_StringCodePoints_Test_fromEnum = M.Data_Enum_fromEnum(M.Data_String_CodePoints_boundedEnumCodePoint)
M.Golden_StringCodePoints_Test_discard = M.Control_Bind_bind(M.Effect_bindEffect)
M.Golden_StringCodePoints_Test_showArray = {
  show = M.Data_Show_foreign.showArrayImpl(M.Data_Show_show(M.Data_Show_showInt))
}
M.Golden_StringCodePoints_Test_logShow = M.Effect_Console_logShow(M.Golden_StringCodePoints_Test_showArray)
M.Golden_StringCodePoints_Test_logShow1 = M.Effect_Console_logShow(M.Data_Show_showInt)
M.Golden_StringCodePoints_Test_logShow2 = M.Effect_Console_logShow(M.Data_Maybe_showMaybe(M.Data_Show_showInt))
M.Golden_StringCodePoints_Test_map = M.Data_Functor_map(M.Data_Maybe_functorMaybe)
M.Golden_StringCodePoints_Test_cp = M.Golden_StringCodePoints_Test_compose(M.Partial_Unsafe_foreign._unsafePartial(function(  )
  return M.Data_Maybe_fromJust()
end))(M.Data_Enum_toEnum(M.Data_String_CodePoints_boundedEnumCodePoint))
M.Golden_StringCodePoints_Test_codes = M.Golden_StringCodePoints_Test_compose(M.Data_Functor_map({
  map = M.Data_Functor_foreign.arrayMap
})(M.Golden_StringCodePoints_Test_fromEnum))(M.Data_String_CodePoints_toCodePointArray)
return (function()
  local _ = M.Golden_StringCodePoints_Test_logShow(M.Golden_StringCodePoints_Test_codes("aéЯ𝐀z"))()
  local _ = M.Golden_StringCodePoints_Test_logShow1(M.Data_String_CodePoints_compose(M.Data_Array_foreign.length)(M.Data_String_CodePoints_toCodePointArray)("aéЯ𝐀z"))()
  local _ = M.Golden_StringCodePoints_Test_logShow1(M.Data_String_CodeUnits_foreign.length("aéЯ𝐀z"))()
  local _ = M.Golden_StringCodePoints_Test_logShow(M.Golden_StringCodePoints_Test_codes(M.Data_String_CodePoints_take_S_w(2, "aéЯ𝐀z")))()
  local _ = M.Golden_StringCodePoints_Test_logShow(M.Golden_StringCodePoints_Test_codes(M.Data_String_CodePoints_drop_S_w(2, "aéЯ𝐀z")))()
  local _ = M.Golden_StringCodePoints_Test_logShow2(M.Golden_StringCodePoints_Test_map(M.Golden_StringCodePoints_Test_fromEnum)(M.Data_String_CodePoints_codePointAt_S_w(0, "aéЯ𝐀z")))()
  local _ = M.Golden_StringCodePoints_Test_logShow2(M.Golden_StringCodePoints_Test_map(M.Golden_StringCodePoints_Test_fromEnum)(M.Data_String_CodePoints_codePointAt_S_w(3, "aéЯ𝐀z")))()
  local _ = M.Golden_StringCodePoints_Test_logShow2(M.Golden_StringCodePoints_Test_map(M.Golden_StringCodePoints_Test_fromEnum)(M.Data_String_CodePoints_codePointAt_S_w(5, "aéЯ𝐀z")))()
  local _ = M.Golden_StringCodePoints_Test_logShow2(M.Golden_StringCodePoints_Test_map(M.Golden_StringCodePoints_Test_compose(M.Golden_StringCodePoints_Test_fromEnum)(function( v_S_0 )
    return v_S_0.head
  end))(M.Data_String_CodePoints_uncons("aéЯ𝐀z")))()
  local _ = M.Effect_Console_logShow_S_w(M.Data_Maybe_showMaybe(M.Golden_StringCodePoints_Test_showArray), M.Golden_StringCodePoints_Test_map(M.Golden_StringCodePoints_Test_compose(M.Golden_StringCodePoints_Test_codes)(function( v0_S_1 )
    return v0_S_1.tail
  end))(M.Data_String_CodePoints_uncons("aéЯ𝐀z")))()
  local _ = M.Effect_Console_logShow_S_w({
    show = function(v_S_1235)
      if v_S_1235 then
        return "true"
      elseif false == v_S_1235 then
        return "false"
      else
        return error("No patterns matched")
      end
    end
  }, M.Data_Eq_eq({
    eq = M.Data_Eq_foreign.eqStringImpl
  })(M.Data_String_CodePoints_foreign._fromCodePointArray(M.Data_String_CodePoints_singletonFallback)(M.Data_String_CodePoints_toCodePointArray("aéЯ𝐀z")))("aéЯ𝐀z"))()
  return M.Golden_StringCodePoints_Test_logShow(M.Golden_StringCodePoints_Test_codes(M.Data_String_CodePoints_singleton(M.Golden_StringCodePoints_Test_cp(119808))))()
end)()
