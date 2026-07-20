local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Data_Functor_map = function(dict) return dict.map end
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
  local _S_cse261 = v[1]
  if "Golden.DerivedFunctor.Test∷Tree.Leaf" == _S_cse261 then
    return 0
  elseif "Golden.DerivedFunctor.Test∷Tree.Node" == _S_cse261 then
    return Golden_DerivedFunctor_Test_sumTree(v[2]) + v[3] + Golden_DerivedFunctor_Test_sumTree(v[4])
  else
    return error("No patterns matched")
  end
end
local Golden_DerivedFunctor_Test_functorTree
Golden_DerivedFunctor_Test_functorTree = {
  map = function(f)
    return function(m)
      local _S_cse263 = Golden_DerivedFunctor_Test_functorTree.map
      local _S_cse262 = m[1]
      if "Golden.DerivedFunctor.Test∷Tree.Leaf" == _S_cse262 then
        return Golden_DerivedFunctor_Test_Leaf
      elseif "Golden.DerivedFunctor.Test∷Tree.Node" == _S_cse262 then
        return Golden_DerivedFunctor_Test_Node_S_w(_S_cse263(f)(m[2]), f(m[3]), _S_cse263(f)(m[4]))
      else
        return error("No patterns matched")
      end
    end
  end
}
local Golden_DerivedFunctor_Test_functorEither = {
  map = function(f)
    return function(m)
      local _S_cse265 = m[2]
      local _S_cse264 = m[1]
      if "Golden.DerivedFunctor.Test∷Either.Left" == _S_cse264 then
        return { "Golden.DerivedFunctor.Test∷Either.Left", _S_cse265 }
      elseif "Golden.DerivedFunctor.Test∷Either.Right" == _S_cse264 then
        return { "Golden.DerivedFunctor.Test∷Either.Right", (f(_S_cse265)) }
      else
        return error("No patterns matched")
      end
    end
  end
}
local Golden_DerivedFunctor_Test_map1 = Data_Functor_map(Golden_DerivedFunctor_Test_functorEither)
local Golden_DerivedFunctor_Test_fromRight_S_w = function(fallback, v)
  local _S_cse266 = v[1]
  if "Golden.DerivedFunctor.Test∷Either.Left" == _S_cse266 then
    return fallback
  elseif "Golden.DerivedFunctor.Test∷Either.Right" == _S_cse266 then
    return v[2]
  else
    return error("No patterns matched")
  end
end
return (function()
  local _S_cse267 = function(v_S_0) return v_S_0 + 1 end
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_fromRight_S_w(0, Golden_DerivedFunctor_Test_map1(_S_cse267)({
    "Golden.DerivedFunctor.Test∷Either.Right",
    41
  }))))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_fromRight_S_w(7, Golden_DerivedFunctor_Test_map1(_S_cse267)({
    "Golden.DerivedFunctor.Test∷Either.Left",
    "no"
  }))))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_sumTree(Golden_DerivedFunctor_Test_functorTree.map(function( v1_S_2 )
    return v1_S_2 * 2
  end)(Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Leaf, 1, Golden_DerivedFunctor_Test_Leaf), 2, Golden_DerivedFunctor_Test_Node_S_w(Golden_DerivedFunctor_Test_Leaf, 3, Golden_DerivedFunctor_Test_Leaf))))))()
end)()
