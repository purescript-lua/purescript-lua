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
local Data_Show_showInt = { show = Data_Show_foreign.showIntImpl }
local Data_Show_show = function(dict) return dict.show end
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
end
local Golden_UncurryCtor_Test_logShow = function(logShow_S_p2_S_325)
  return Effect_Console_logShow_S_w(Data_Show_showInt, logShow_S_p2_S_325)
end
local Golden_UncurryCtor_Test_Origin = {
  "Golden.UncurryCtor.Test∷Shape.Origin"
}
local Golden_UncurryCtor_Test_Dot = function(value0)
  return { "Golden.UncurryCtor.Test∷Shape.Dot", value0 }
end
local Golden_UncurryCtor_Test_Tri_S_w = function(value0, value1, value2)
  return { "Golden.UncurryCtor.Test∷Shape.Tri", value0, value1, value2 }
end
local Golden_UncurryCtor_Test_Tri = function(Tri_S_p1)
  return function(Tri_S_p2)
    return function(Tri_S_p3)
      return Golden_UncurryCtor_Test_Tri_S_w(Tri_S_p1, Tri_S_p2, Tri_S_p3)
    end
  end
end
local Golden_UncurryCtor_Test_Pair_S_w = function(value0, value1)
  return { value0, value1 }
end
local Golden_UncurryCtor_Test_Nil = { "Golden.UncurryCtor.Test∷IntList.Nil" }
local Golden_UncurryCtor_Test_Cons_S_w = function(value0, value1)
  return { "Golden.UncurryCtor.Test∷IntList.Cons", value0, value1 }
end
local Golden_UncurryCtor_Test_unbox = function(v) return v end
local Golden_UncurryCtor_Test_total
Golden_UncurryCtor_Test_total = function(v)
  if "Golden.UncurryCtor.Test∷IntList.Nil" == v[1] then
    return 0
  else
    return v[2] + Golden_UncurryCtor_Test_total(v[3])
  end
end
local Golden_UncurryCtor_Test_range = Golden_UncurryCtor_Test_Cons_S_w(1, Golden_UncurryCtor_Test_Cons_S_w(2, Golden_UncurryCtor_Test_Cons_S_w(3, Golden_UncurryCtor_Test_Cons_S_w(4, Golden_UncurryCtor_Test_Cons_S_w(5, Golden_UncurryCtor_Test_Cons_S_w(6, Golden_UncurryCtor_Test_Cons_S_w(7, Golden_UncurryCtor_Test_Cons_S_w(8, Golden_UncurryCtor_Test_Cons_S_w(9, Golden_UncurryCtor_Test_Cons_S_w(10, Golden_UncurryCtor_Test_Nil))))))))))
local Golden_UncurryCtor_Test_pairSum = function(v) return v[1] + v[2] end
local Golden_UncurryCtor_Test_area = function(v)
  local _S_cse433 = v[2]
  local _S_cse432 = v[1]
  if "Golden.UncurryCtor.Test∷Shape.Origin" == _S_cse432 then
    return 0
  elseif "Golden.UncurryCtor.Test∷Shape.Dot" == _S_cse432 then
    return _S_cse433
  else
    return _S_cse433 + v[3] + v[4]
  end
end
return (function()
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_area(Golden_UncurryCtor_Test_Tri_S_w(3, 4, 5)))()
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_area(Golden_UncurryCtor_Test_Dot(9)))()
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_area(Golden_UncurryCtor_Test_Origin))()
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_pairSum(Golden_UncurryCtor_Test_Pair_S_w(20, 22)))()
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_unbox(41))()
  local mk_S_0 = Golden_UncurryCtor_Test_Tri(1)(2)
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_area(mk_S_0(3)))()
  local _ = Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_area(mk_S_0(30)))()
  local _ = Effect_Console_logShow_S_w({
    show = Data_Show_foreign.showArrayImpl(Data_Show_show(Data_Show_showInt))
  }, Data_Functor_arrayMap(function(v2_S_307)
    if "Data.Maybe∷Maybe.Nothing" == v2_S_307[1] then
      return 0
    else
      return v2_S_307[2]
    end
  end)(Data_Functor_arrayMap(function(value0_S_308)
    return { "Data.Maybe∷Maybe.Just", value0_S_308 }
  end)({ [1] = 1, [2] = 2, [3] = 3 })))()
  return Golden_UncurryCtor_Test_logShow(Golden_UncurryCtor_Test_total(Golden_UncurryCtor_Test_range))()
end)()
