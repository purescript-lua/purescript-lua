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
local Data_Unit_unit = {}
local Data_Semigroup_foreign = {
  concatArray = function(xs)
    return function(ys)
      if #(xs) == 0 then return ys end
      if #(ys) == 0 then return xs end
      local result = {}
      for index, value in ipairs(xs) do result[index] = value end
      local offset = #(result)
      for index, value in ipairs(ys) do result[index + offset] = value end
      return result
    end
  end
}
local Data_Show_showIntImpl = function(n) return tostring(n) end
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
local Data_EuclideanRing_intDiv = Data_EuclideanRing_foreign.intDiv
local Data_EuclideanRing_intMod = Data_EuclideanRing_foreign.intMod
local Data_Show_Generic_foreign = {
  intercalate = function(sep)
    return function(xs) return table.concat(xs, sep) end
  end
}
local Effect_foreign = {
  pureE = function(a) return function() return a end end,
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end
}
local Effect_Console_log = function(s) return function() print(s) end end
local Effect_Ref_foreign = {
  _new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  modifyImpl = function(f)
    return function(ref)
      return function()
        local t = f(ref.value)
        ref.value = t.state
        return t.value
      end
    end
  end
}
local Data_Semigroup_semigroupString = {
  append = function(s1_S_0)
    return function(s2_S_0) return s1_S_0 .. s2_S_0 end
  end
}
local Data_Show_show = function(dict) return dict.show end
local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
local Effect_bindEffect
local Effect_applicativeEffect
local Effect_monadEffect = {
  Applicative0 = function() return Effect_applicativeEffect end,
  Bind1 = function() return Effect_bindEffect end
}
local Effect_Lazy_applyEffect
Effect_bindEffect = {
  bind = Effect_foreign.bindE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
Effect_applicativeEffect = {
  pure = Effect_foreign.pureE,
  Apply0 = function() return Effect_Lazy_applyEffect(0) end
}
local Effect_Lazy_functorEffect = PSLUA_runtime_lazy("functorEffect")(function()
  return {
    map = function(f_S_0)
      return function(a_S_0)
        return (Effect_applicativeEffect.Apply0()).apply(Effect_applicativeEffect.pure(f_S_0))(a_S_0)
      end
    end
  }
end)
Effect_Lazy_applyEffect = PSLUA_runtime_lazy("applyEffect")(function()
  return {
    apply = (function()
      local bind_S_0 = (Effect_monadEffect.Bind1()).bind
      return function(f_S_1)
        return function(a_S_1)
          return bind_S_0(f_S_1)(function(fPrime_S_0)
            return bind_S_0(a_S_1)(function(aPrime_S_0)
              return (Effect_monadEffect.Applicative0()).pure(fPrime_S_0(aPrime_S_0))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function() return Effect_Lazy_functorEffect(0) end
  }
end)
local Effect_functorEffect = Effect_Lazy_functorEffect(0)
local Golden_DirectivePack_Test_show = Data_Show_showIntImpl
local Golden_DirectivePack_Test_Apple = {
  "Golden.DirectivePack.Test∷Fruit.Apple"
}
M.Golden_DirectivePack_Test_Banana = function(value0)
  return { "Golden.DirectivePack.Test∷Fruit.Banana", value0 }
end
M.Golden_DirectivePack_Test_genericFruit_ = {
  to = function(x)
    if "Data.Generic.Rep∷Sum.Inl" == x[1] then
      return Golden_DirectivePack_Test_Apple
    else
      return { "Golden.DirectivePack.Test∷Fruit.Banana", x[2] }
    end
  end,
  from = function(x0)
    if "Golden.DirectivePack.Test∷Fruit.Apple" == x0[1] then
      return { "Data.Generic.Rep∷Sum.Inl", {} }
    else
      return { "Data.Generic.Rep∷Sum.Inr", x0[2] }
    end
  end
}
local Golden_DirectivePack_Test_showFruit = {
  show = function(x_S_0)
    local v_S_0 = (function()
      if "Golden.DirectivePack.Test∷Fruit.Apple" == x_S_0[1] then
        return { "Data.Generic.Rep∷Sum.Inl", {} }
      else
        return { "Data.Generic.Rep∷Sum.Inr", x_S_0[2] }
      end
    end)()
    if "Data.Generic.Rep∷Sum.Inl" == v_S_0[1] then
      return "Apple"
    else
      local v1_S_0 = { [1] = Data_Show_showIntImpl(v_S_0[2]) }
      if 0 == #(v1_S_0) then
        return "Banana"
      else
        return "(" .. Data_Show_Generic_foreign.intercalate(" ")(Data_Semigroup_foreign.concatArray({
          [1] = "Banana"
        })(v1_S_0)) .. ")"
      end
    end
  end
}
local Golden_DirectivePack_Test_pipeline = function(x_S_1) return x_S_1 + 1 end
M.Golden_DirectivePack_Test_half = function(n)
  if Data_EuclideanRing_intMod(n)(2) == 0 then
    return { "Data.Maybe∷Maybe.Just", (Data_EuclideanRing_intDiv(n)(2)) }
  else
    return Data_Maybe_Nothing
  end
end
local Golden_DirectivePack_Test_describeFruit = function(x_S_2)
  return Data_Semigroup_semigroupString.append("fruit: ")(Data_Show_show(Golden_DirectivePack_Test_showFruit)(x_S_2))
end
M.Golden_DirectivePack_Test_classify = function(n)
  if n < 0 then
    return "negative"
  elseif n == 0 then
    return "zero"
  else
    return "positive"
  end
end
local Golden_DirectivePack_Test_chain = (function()
  local a_S_3 = (function()
    local a_S_2 = (function()
      if Data_EuclideanRing_intMod(40)(2) == 0 then
        return { "Data.Maybe∷Maybe.Just", (Data_EuclideanRing_intDiv(40)(2)) }
      else
        return Data_Maybe_Nothing
      end
    end)()
    if "Data.Maybe∷Maybe.Just" == a_S_2[1] then
      if Data_EuclideanRing_intMod(a_S_2[2])(2) == 0 then
        return {
          "Data.Maybe∷Maybe.Just",
          (Data_EuclideanRing_intDiv(a_S_2[2])(2))
        }
      else
        return Data_Maybe_Nothing
      end
    else
      return Data_Maybe_Nothing
    end
  end)()
  if "Data.Maybe∷Maybe.Just" == a_S_3[1] then
    if Data_EuclideanRing_intMod(a_S_3[2])(2) == 0 then
      return {
        "Data.Maybe∷Maybe.Just",
        (Data_EuclideanRing_intDiv(a_S_3[2])(2))
      }
    else
      return Data_Maybe_Nothing
    end
  else
    return Data_Maybe_Nothing
  end
end)()
return (function()
  local _ = Effect_Console_log((function()
    if "Data.Maybe∷Maybe.Just" == Golden_DirectivePack_Test_chain[1] then
      return "(Just " .. Data_Show_showIntImpl(Golden_DirectivePack_Test_chain[2]) .. ")"
    else
      return "Nothing"
    end
  end)())()
  local _ = Effect_Console_log(Golden_DirectivePack_Test_describeFruit({
    "Golden.DirectivePack.Test∷Fruit.Banana",
    3
  }))()
  local _ = Effect_Console_log(Golden_DirectivePack_Test_show(Golden_DirectivePack_Test_pipeline(41)))()
  local _ = Effect_Console_log("positive")()
  local r_S_0 = Effect_Ref_foreign._new(10)()
  local _ = Effect_functorEffect.map(function()
    return Data_Unit_unit
  end)(Effect_Ref_foreign.modifyImpl(function(s_S_0)
    local sPrime_S_0 = s_S_0 * 3
    return { state = sPrime_S_0, value = sPrime_S_0 }
  end)(r_S_0))()
  local v0_S_0 = Effect_Ref_foreign.read(r_S_0)()
  return Effect_Console_log(Golden_DirectivePack_Test_show(v0_S_0))()
end)()
