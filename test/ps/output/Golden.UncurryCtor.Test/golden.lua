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
local Golden_UncurryCtor_Test_Origin = {
  "Golden.UncurryCtor.Test∷Shape.Origin"
}
M.Golden_UncurryCtor_Test_Dot = function(value0)
  return { "Golden.UncurryCtor.Test∷Shape.Dot", value0 }
end
local Golden_UncurryCtor_Test_Tri_S_w = function(value0, value1, value2)
  return { "Golden.UncurryCtor.Test∷Shape.Tri", value0, value1, value2 }
end
M.Golden_UncurryCtor_Test_Tri = function(Tri_S_p1)
  return function(Tri_S_p2)
    return function(Tri_S_p3)
      return Golden_UncurryCtor_Test_Tri_S_w(Tri_S_p1, Tri_S_p2, Tri_S_p3)
    end
  end
end
M.Golden_UncurryCtor_Test_Pair_S_w = function(value0, value1)
  return { value0, value1 }
end
local Golden_UncurryCtor_Test_Nil = { "Golden.UncurryCtor.Test∷IntList.Nil" }
local Golden_UncurryCtor_Test_Cons_S_w = function(value0, value1)
  return { "Golden.UncurryCtor.Test∷IntList.Cons", value0, value1 }
end
M.Golden_UncurryCtor_Test_unbox = function(v) return v end
local Golden_UncurryCtor_Test_total
Golden_UncurryCtor_Test_total = function(v)
  local _S_cse394 = v[1]
  if "Golden.UncurryCtor.Test∷IntList.Nil" == _S_cse394 then
    return 0
  elseif "Golden.UncurryCtor.Test∷IntList.Cons" == _S_cse394 then
    return v[2] + Golden_UncurryCtor_Test_total(v[3])
  else
    return error("No patterns matched")
  end
end
local Golden_UncurryCtor_Test_range = Golden_UncurryCtor_Test_Cons_S_w(1, Golden_UncurryCtor_Test_Cons_S_w(2, Golden_UncurryCtor_Test_Cons_S_w(3, Golden_UncurryCtor_Test_Cons_S_w(4, Golden_UncurryCtor_Test_Cons_S_w(5, Golden_UncurryCtor_Test_Cons_S_w(6, Golden_UncurryCtor_Test_Cons_S_w(7, Golden_UncurryCtor_Test_Cons_S_w(8, Golden_UncurryCtor_Test_Cons_S_w(9, Golden_UncurryCtor_Test_Cons_S_w(10, Golden_UncurryCtor_Test_Nil))))))))))
M.Golden_UncurryCtor_Test_pairSum = function(v) return v[1] + v[2] end
M.Golden_UncurryCtor_Test_area = function(v)
  local _S_cse396 = v[2]
  local _S_cse395 = v[1]
  if "Golden.UncurryCtor.Test∷Shape.Origin" == _S_cse395 then
    return 0
  elseif "Golden.UncurryCtor.Test∷Shape.Dot" == _S_cse395 then
    return _S_cse396
  elseif "Golden.UncurryCtor.Test∷Shape.Tri" == _S_cse395 then
    return _S_cse396 + v[3] + v[4]
  else
    return error("No patterns matched")
  end
end
return (function()
  local _S_cse398 = Golden_UncurryCtor_Test_Origin[2]
  local _S_cse397 = Golden_UncurryCtor_Test_Origin[1]
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, 12)()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    local v_S_345 = { "Golden.UncurryCtor.Test∷Shape.Dot", 9 }
    if "Golden.UncurryCtor.Test∷Shape.Origin" == v_S_345[1] then
      return 0
    elseif "Golden.UncurryCtor.Test∷Shape.Dot" == v_S_345[1] then
      return v_S_345[2]
    elseif "Golden.UncurryCtor.Test∷Shape.Tri" == v_S_345[1] then
      return v_S_345[2] + v_S_345[3] + v_S_345[4]
    else
      return error("No patterns matched")
    end
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
    if "Golden.UncurryCtor.Test∷Shape.Origin" == _S_cse397 then
      return 0
    elseif "Golden.UncurryCtor.Test∷Shape.Dot" == _S_cse397 then
      return _S_cse398
    elseif "Golden.UncurryCtor.Test∷Shape.Tri" == _S_cse397 then
      return _S_cse398 + Golden_UncurryCtor_Test_Origin[3] + Golden_UncurryCtor_Test_Origin[4]
    else
      return error("No patterns matched")
    end
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, 42)()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, 41)()
  return (function()
    local mk_S_0_S_r = function(Tri_S_p3_S_367) return 1, 2, Tri_S_p3_S_367 end
    return function()
      local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
        local _S_v382, _S_v383, _S_v384 = mk_S_0_S_r(3)
        return _S_v382 + _S_v383 + _S_v384
      end)())()
      local _ = Effect_Console_logShow_S_w(Data_Show_showInt, (function()
        local _S_v385, _S_v386, _S_v387 = mk_S_0_S_r(30)
        return _S_v385 + _S_v386 + _S_v387
      end)())()
      local _ = Effect_Console_logShow_S_w({
        show = Data_Show_foreign.showArrayImpl(Data_Show_showIntImpl)
      }, Data_Functor_arrayMap(function(v2_S_307)
        local _S_cse399 = v2_S_307[1]
        if "Data.Maybe∷Maybe.Nothing" == _S_cse399 then
          return 0
        elseif "Data.Maybe∷Maybe.Just" == _S_cse399 then
          return v2_S_307[2]
        else
          return error("No patterns matched")
        end
      end)(Data_Functor_arrayMap(function(value0_S_308)
        return { "Data.Maybe∷Maybe.Just", value0_S_308 }
      end)({ [1] = 1, [2] = 2, [3] = 3 })))()
      return Effect_Console_logShow_S_w(Data_Show_showInt, Golden_UncurryCtor_Test_total(Golden_UncurryCtor_Test_range))()
    end
  end)()()
end)()
