local M = {}
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
local Data_Functor_arrayMap = Data_Functor_foreign.arrayMap
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Show_showInt = { show = Data_Show_showIntImpl }
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
end
local Golden_UncurryCtor_Test_add_S_w = function(x_S_308, y_S_309)
  return x_S_308 + y_S_309
end
local Golden_UncurryCtor_Test_Origin = {
  "Golden.UncurryCtor.Test∷Shape.Origin"
}
local Golden_UncurryCtor_Test_Dot = function(value0)
  return { "Golden.UncurryCtor.Test∷Shape.Dot", value0 }
end
local Golden_UncurryCtor_Test_Tri = function(value0)
  return function(value1)
    return function(value2)
      return { "Golden.UncurryCtor.Test∷Shape.Tri", value0, value1, value2 }
    end
  end
end
M.Golden_UncurryCtor_Test_Pair = function(value0)
  return function(value1) return { value0, value1 } end
end
local Golden_UncurryCtor_Test_Nil = { "Golden.UncurryCtor.Test∷IntList.Nil" }
local Golden_UncurryCtor_Test_Cons = function(value0)
  return function(value1)
    return { "Golden.UncurryCtor.Test∷IntList.Cons", value0, value1 }
  end
end
M.Golden_UncurryCtor_Test_unbox = function(v) return v end
local Golden_UncurryCtor_Test_total
Golden_UncurryCtor_Test_total = function(v)
  local _S_cse341 = v[1]
  if "Golden.UncurryCtor.Test∷IntList.Nil" == _S_cse341 then
    return 0
  elseif "Golden.UncurryCtor.Test∷IntList.Cons" == _S_cse341 then
    return Golden_UncurryCtor_Test_add_S_w(v[2], Golden_UncurryCtor_Test_total(v[3]))
  else
    return error("No patterns matched")
  end
end
local Golden_UncurryCtor_Test_range = Golden_UncurryCtor_Test_Cons(1)(Golden_UncurryCtor_Test_Cons(2)(Golden_UncurryCtor_Test_Cons(3)(Golden_UncurryCtor_Test_Cons(4)(Golden_UncurryCtor_Test_Cons(5)(Golden_UncurryCtor_Test_Cons(6)(Golden_UncurryCtor_Test_Cons(7)(Golden_UncurryCtor_Test_Cons(8)(Golden_UncurryCtor_Test_Cons(9)(Golden_UncurryCtor_Test_Cons(10)(Golden_UncurryCtor_Test_Nil))))))))))
M.Golden_UncurryCtor_Test_pairSum = function(v)
  return Golden_UncurryCtor_Test_add_S_w(v[1], v[2])
end
M.Golden_UncurryCtor_Test_area = function(v)
  local _S_cse343 = v[2]
  local _S_cse342 = v[1]
  if "Golden.UncurryCtor.Test∷Shape.Origin" == _S_cse342 then
    return 0
  elseif "Golden.UncurryCtor.Test∷Shape.Dot" == _S_cse342 then
    return _S_cse343
  elseif "Golden.UncurryCtor.Test∷Shape.Tri" == _S_cse342 then
    return Golden_UncurryCtor_Test_add_S_w(Golden_UncurryCtor_Test_add_S_w(_S_cse343, v[3]), v[4])
  else
    return error("No patterns matched")
  end
end
return (function()
  local _S_cse345 = Golden_UncurryCtor_Test_Origin[2]
  local _S_cse344 = Golden_UncurryCtor_Test_Origin[1]
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_UncurryCtor_Test_add_S_w(Golden_UncurryCtor_Test_add_S_w(3, 4), 5))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    local v_S_325 = Golden_UncurryCtor_Test_Dot(9)
    if "Golden.UncurryCtor.Test∷Shape.Origin" == v_S_325[1] then
      return 0
    elseif "Golden.UncurryCtor.Test∷Shape.Dot" == v_S_325[1] then
      return v_S_325[2]
    elseif "Golden.UncurryCtor.Test∷Shape.Tri" == v_S_325[1] then
      return Golden_UncurryCtor_Test_add_S_w(Golden_UncurryCtor_Test_add_S_w(v_S_325[2], v_S_325[3]), v_S_325[4])
    else
      return error("No patterns matched")
    end
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    if "Golden.UncurryCtor.Test∷Shape.Origin" == _S_cse344 then
      return 0
    elseif "Golden.UncurryCtor.Test∷Shape.Dot" == _S_cse344 then
      return _S_cse345
    elseif "Golden.UncurryCtor.Test∷Shape.Tri" == _S_cse344 then
      return Golden_UncurryCtor_Test_add_S_w(Golden_UncurryCtor_Test_add_S_w(_S_cse345, Golden_UncurryCtor_Test_Origin[3]), Golden_UncurryCtor_Test_Origin[4])
    else
      return error("No patterns matched")
    end
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_UncurryCtor_Test_add_S_w(20, 22))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, 41)()
  return (function()
    local mk_S_0 = Golden_UncurryCtor_Test_Tri(1)(2)
    return function()
      local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
        local v_S_335 = mk_S_0(3)
        if "Golden.UncurryCtor.Test∷Shape.Origin" == v_S_335[1] then
          return 0
        elseif "Golden.UncurryCtor.Test∷Shape.Dot" == v_S_335[1] then
          return v_S_335[2]
        elseif "Golden.UncurryCtor.Test∷Shape.Tri" == v_S_335[1] then
          return Golden_UncurryCtor_Test_add_S_w(Golden_UncurryCtor_Test_add_S_w(v_S_335[2], v_S_335[3]), v_S_335[4])
        else
          return error("No patterns matched")
        end
      end)())()
      local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
        local v_S_337 = mk_S_0(30)
        if "Golden.UncurryCtor.Test∷Shape.Origin" == v_S_337[1] then
          return 0
        elseif "Golden.UncurryCtor.Test∷Shape.Dot" == v_S_337[1] then
          return v_S_337[2]
        elseif "Golden.UncurryCtor.Test∷Shape.Tri" == v_S_337[1] then
          return Golden_UncurryCtor_Test_add_S_w(Golden_UncurryCtor_Test_add_S_w(v_S_337[2], v_S_337[3]), v_S_337[4])
        else
          return error("No patterns matched")
        end
      end)())()
      local _ = Effect_Console_logShow_S_w({
        show = Data_Show_foreign.showArrayImpl(Data_Show_showIntImpl)
      }, Data_Functor_arrayMap(function(v2_S_305)
        local _S_cse346 = v2_S_305[1]
        if "Data.Maybe∷Maybe.Nothing" == _S_cse346 then
          return 0
        elseif "Data.Maybe∷Maybe.Just" == _S_cse346 then
          return v2_S_305[2]
        else
          return error("No patterns matched")
        end
      end)(Data_Functor_arrayMap(function(value0)
        return { "Data.Maybe∷Maybe.Just", value0 }
      end)({ [1] = 1, [2] = 2, [3] = 3 })))()
      return Effect_Console_logShow_S_w(Data_Show_showInt, Golden_UncurryCtor_Test_total(Golden_UncurryCtor_Test_range))()
    end
  end)()()
end)()
