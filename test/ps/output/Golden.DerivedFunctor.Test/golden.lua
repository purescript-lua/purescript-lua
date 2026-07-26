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
  if "Golden.DerivedFunctor.Test∷Tree.Leaf" == v[1] then
    return 0
  else
    return Golden_DerivedFunctor_Test_sumTree(v[2]) + v[3] + Golden_DerivedFunctor_Test_sumTree(v[4])
  end
end
local Golden_DerivedFunctor_Test_functorTree
Golden_DerivedFunctor_Test_functorTree = {
  map = function(f)
    return function(m)
      local _S_cse0 = Golden_DerivedFunctor_Test_functorTree.map
      if "Golden.DerivedFunctor.Test∷Tree.Leaf" == m[1] then
        return Golden_DerivedFunctor_Test_Leaf
      else
        return Golden_DerivedFunctor_Test_Node_S_w(_S_cse0(f)(m[2]), f(m[3]), _S_cse0(f)(m[4]))
      end
    end
  end
}
M.Golden_DerivedFunctor_Test_functorEither = {
  map = function(f)
    return function(m)
      local _S_cse1 = m[2]
      if "Golden.DerivedFunctor.Test∷Either.Left" == m[1] then
        return { "Golden.DerivedFunctor.Test∷Either.Left", _S_cse1 }
      else
        return { "Golden.DerivedFunctor.Test∷Either.Right", (f(_S_cse1)) }
      end
    end
  end
}
local Golden_DerivedFunctor_Test_fromRight_S_w = function(fallback, v)
  if "Golden.DerivedFunctor.Test∷Either.Left" == v[1] then
    return fallback
  else
    return v[2]
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
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_sumTree(Golden_DerivedFunctor_Test_functorTree.map(function( v1_S_0 )
    return v1_S_0 * 2
  end)(Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Leaf, 1, Golden_DerivedFunctor_Test_Leaf), 2, Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Leaf, 3, Golden_DerivedFunctor_Test_Leaf))))))()
end)()
