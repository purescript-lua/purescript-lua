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
local Data_Semigroup_concatArray = Data_Semigroup_foreign.concatArray
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
local Data_Functor_arrayMap = Data_Functor_foreign.arrayMap
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_CSE_Test_runTwice = function(r)
  return function(x) return r.run(r.run(x)) end
end
local Golden_CSE_Test_catBoth = function(f)
  return Data_Semigroup_concatArray(f({ [1] = 1, [2] = 2, [3] = 3 }))(f({
    [1] = 1,
    [2] = 2,
    [3] = 3
  }))
end
local Golden_CSE_Test_addToAll = function(n)
  return function(xs)
    return Data_Semigroup_concatArray(Data_Functor_arrayMap(function(i)
      return i + n
    end)(xs))(Data_Functor_arrayMap(function(i0) return i0 + n end)(xs))
  end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showArrayImpl(Data_Show_showIntImpl)(Golden_CSE_Test_addToAll(10)({
    [1] = 1,
    [2] = 2
  })))()
  local _ = Effect_Console_log(Data_Show_showArrayImpl(Data_Show_showIntImpl)(Golden_CSE_Test_addToAll(20)({
    [1] = 3
  })))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_CSE_Test_runTwice({
    run = function(i_S_0) return i_S_0 * 2 end
  })(3)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_CSE_Test_runTwice({
    run = function(i0_S_1) return i0_S_1 - 1 end
  })(10)))()
  local _ = Effect_Console_log(Data_Show_showArrayImpl(Data_Show_showIntImpl)(Golden_CSE_Test_catBoth(Data_Functor_arrayMap(function( v_S_2 )
    return v_S_2 * 3
  end))))()
  return Effect_Console_log(Data_Show_showArrayImpl(Data_Show_showIntImpl)(Golden_CSE_Test_catBoth(function( x_S_216 )
    return x_S_216
  end)))()
end)()
