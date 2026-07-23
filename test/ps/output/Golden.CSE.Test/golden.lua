local M = {}
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
local Golden_CSE_Test_logShow = function(a_S_230)
  return Effect_Console_log(Data_Show_foreign.showArrayImpl(Data_Show_showIntImpl)(a_S_230))
end
local Golden_CSE_Test_logShow1 = function(a_S_226)
  return Effect_Console_log(Data_Show_showIntImpl(a_S_226))
end
local Golden_CSE_Test_Zero = { "Golden.CSE.Test∷N.Zero" }
M.Golden_CSE_Test_Succ = function(value0)
  return { "Golden.CSE.Test∷N.Succ", value0 }
end
M.Golden_CSE_Test_Num = function(value0)
  return { "Golden.CSE.Test∷E.Num", value0 }
end
M.Golden_CSE_Test_Not = function(value0)
  return { "Golden.CSE.Test∷E.Not", value0 }
end
local Golden_CSE_Test_runTwice = function(r)
  return function(x) local _S_cse265 = r.run return _S_cse265(_S_cse265(x)) end
end
local Golden_CSE_Test_classify = function(e)
  local _S_cse266 = e[2]
  if "Golden.CSE.Test∷E.Not" == e[1] then
    if "Golden.CSE.Test∷E.Num" == _S_cse266[1] then
      if "Golden.CSE.Test∷N.Zero" == _S_cse266[2][1] then
        return 0
      elseif "Golden.CSE.Test∷N.Succ" == _S_cse266[2][1] then
        return 1
      else
        return error("No patterns matched")
      end
    elseif "Golden.CSE.Test∷E.Not" == _S_cse266[1] then
      return 2
    else
      return error("No patterns matched")
    end
  elseif "Golden.CSE.Test∷N.Zero" == _S_cse266[1] then
    return 3
  elseif "Golden.CSE.Test∷N.Succ" == _S_cse266[1] then
    return 4
  else
    return error("No patterns matched")
  end
end
local Golden_CSE_Test_catBoth = function(f)
  local _S_cse267 = { [1] = 1, [2] = 2, [3] = 3 }
  return Data_Semigroup_concatArray(f(_S_cse267))(f(_S_cse267))
end
local Golden_CSE_Test_addToAll = function(n)
  return function(xs)
    local _S_cse268 = function(i) return i + n end
    return Data_Semigroup_concatArray(Data_Functor_arrayMap(_S_cse268)(xs))(Data_Functor_arrayMap(_S_cse268)(xs))
  end
end
return (function()
  local _S_cse270 = { "Golden.CSE.Test∷E.Num", Golden_CSE_Test_Zero }
  local _S_cse269 = { "Golden.CSE.Test∷E.Not", _S_cse270 }
  local _ = Golden_CSE_Test_logShow(Golden_CSE_Test_addToAll(10)({
    [1] = 1,
    [2] = 2
  }))()
  local _ = Golden_CSE_Test_logShow(Golden_CSE_Test_addToAll(20)({ [1] = 3 }))()
  local _ = Golden_CSE_Test_logShow1(Golden_CSE_Test_runTwice({
    run = function(i_S_0) return i_S_0 * 2 end
  })(3))()
  local _ = Golden_CSE_Test_logShow1(Golden_CSE_Test_runTwice({
    run = function(i0_S_1) return i0_S_1 - 1 end
  })(10))()
  local _ = Golden_CSE_Test_logShow(Golden_CSE_Test_catBoth(Data_Functor_arrayMap(function( v_S_2 )
    return v_S_2 * 3
  end)))()
  local _ = Golden_CSE_Test_logShow(Golden_CSE_Test_catBoth(function(x_S_216)
    return x_S_216
  end))()
  local _ = Golden_CSE_Test_logShow1(Golden_CSE_Test_classify(_S_cse270))()
  local _ = Golden_CSE_Test_logShow1(Golden_CSE_Test_classify({
    "Golden.CSE.Test∷E.Num",
    { "Golden.CSE.Test∷N.Succ", Golden_CSE_Test_Zero }
  }))()
  local _ = Golden_CSE_Test_logShow1(Golden_CSE_Test_classify(_S_cse269))()
  return Golden_CSE_Test_logShow1(Golden_CSE_Test_classify({
    "Golden.CSE.Test∷E.Not",
    _S_cse269
  }))()
end)()
