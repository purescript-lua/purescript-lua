local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_DerivedFunctor_Test_Leaf = {
  "Golden.DerivedFunctor.Test∷Tree.Leaf"
}
local Golden_DerivedFunctor_Test_Node_S_w = function(value0, value1, value2)
  return { "Golden.DerivedFunctor.Test∷Tree.Node", value0, value1, value2 }
end
M.Golden_DerivedFunctor_Test_Left = function(value0)
  return { "Golden.DerivedFunctor.Test∷Either.Left", value0 }
end
M.Golden_DerivedFunctor_Test_Right = function(value0)
  return { "Golden.DerivedFunctor.Test∷Either.Right", value0 }
end
local Golden_DerivedFunctor_Test_sumTree
Golden_DerivedFunctor_Test_sumTree = function(v)
  local _S_cse250 = v[1]
  if "Golden.DerivedFunctor.Test∷Tree.Leaf" == _S_cse250 then
    return 0
  elseif "Golden.DerivedFunctor.Test∷Tree.Node" == _S_cse250 then
    return Golden_DerivedFunctor_Test_sumTree(v[2]) + v[3] + Golden_DerivedFunctor_Test_sumTree(v[4])
  else
    return error("No patterns matched")
  end
end
local Golden_DerivedFunctor_Test_functorTree
Golden_DerivedFunctor_Test_functorTree = {
  map = function(f)
    return function(m)
      local _S_cse252 = Golden_DerivedFunctor_Test_functorTree.map
      local _S_cse251 = m[1]
      if "Golden.DerivedFunctor.Test∷Tree.Leaf" == _S_cse251 then
        return Golden_DerivedFunctor_Test_Leaf
      elseif "Golden.DerivedFunctor.Test∷Tree.Node" == _S_cse251 then
        return Golden_DerivedFunctor_Test_Node_S_w(_S_cse252(f)(m[2]), f(m[3]), _S_cse252(f)(m[4]))
      else
        return error("No patterns matched")
      end
    end
  end
}
M.Golden_DerivedFunctor_Test_functorEither = {
  map = function(f)
    return function(m)
      local _S_cse254 = m[2]
      local _S_cse253 = m[1]
      if "Golden.DerivedFunctor.Test∷Either.Left" == _S_cse253 then
        return { "Golden.DerivedFunctor.Test∷Either.Left", _S_cse254 }
      elseif "Golden.DerivedFunctor.Test∷Either.Right" == _S_cse253 then
        return { "Golden.DerivedFunctor.Test∷Either.Right", (f(_S_cse254)) }
      else
        return error("No patterns matched")
      end
    end
  end
}
local Golden_DerivedFunctor_Test_fromRight_S_w = function(fallback, v)
  local _S_cse255 = v[1]
  if "Golden.DerivedFunctor.Test∷Either.Left" == _S_cse255 then
    return fallback
  elseif "Golden.DerivedFunctor.Test∷Either.Right" == _S_cse255 then
    return v[2]
  else
    return error("No patterns matched")
  end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_fromRight_S_w(0, {
    "Golden.DerivedFunctor.Test∷Either.Right",
    42
  })))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_fromRight_S_w(7, {
    "Golden.DerivedFunctor.Test∷Either.Left",
    "no"
  })))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_sumTree(Golden_DerivedFunctor_Test_functorTree.map(function( v1_S_2 )
    return v1_S_2 * 2
  end)(Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Leaf, 1, Golden_DerivedFunctor_Test_Leaf), 2, Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Leaf, 3, Golden_DerivedFunctor_Test_Leaf))))))()
end)()
