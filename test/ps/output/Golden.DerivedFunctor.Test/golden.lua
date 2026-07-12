local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_DerivedFunctor_Test_Leaf = {
  ["$ctor"] = "Golden.DerivedFunctor.Test∷Tree.Leaf"
}
local Golden_DerivedFunctor_Test_Node = function(value0)
  return function(value1)
    return function(value2)
      return {
        ["$ctor"] = "Golden.DerivedFunctor.Test∷Tree.Node",
        value0 = value0,
        value1 = value1,
        value2 = value2
      }
    end
  end
end
local Golden_DerivedFunctor_Test_Left = function(value0)
  return {
    ["$ctor"] = "Golden.DerivedFunctor.Test∷Either.Left",
    value0 = value0
  }
end
local Golden_DerivedFunctor_Test_Right = function(value0)
  return {
    ["$ctor"] = "Golden.DerivedFunctor.Test∷Either.Right",
    value0 = value0
  }
end
local Golden_DerivedFunctor_Test_sumTree
Golden_DerivedFunctor_Test_sumTree = function(v)
  if "Golden.DerivedFunctor.Test∷Tree.Leaf" == v["$ctor"] then
    return 0
  elseif "Golden.DerivedFunctor.Test∷Tree.Node" == v["$ctor"] then
    return Golden_DerivedFunctor_Test_sumTree(v.value0) + v.value1 + Golden_DerivedFunctor_Test_sumTree(v.value2)
  else
    return error("No patterns matched")
  end
end
local Golden_DerivedFunctor_Test_functorTree
Golden_DerivedFunctor_Test_functorTree = {
  map = function(f)
    return function(m)
      if "Golden.DerivedFunctor.Test∷Tree.Leaf" == m["$ctor"] then
        return Golden_DerivedFunctor_Test_Leaf
      elseif "Golden.DerivedFunctor.Test∷Tree.Node" == m["$ctor"] then
        return Golden_DerivedFunctor_Test_Node(Golden_DerivedFunctor_Test_functorTree.map(f)(m.value0))(f(m.value1))(Golden_DerivedFunctor_Test_functorTree.map(f)(m.value2))
      else
        return error("No patterns matched")
      end
    end
  end
}
M.Golden_DerivedFunctor_Test_functorEither = {
  map = function(f)
    return function(m)
      if "Golden.DerivedFunctor.Test∷Either.Left" == m["$ctor"] then
        return Golden_DerivedFunctor_Test_Left(m.value0)
      elseif "Golden.DerivedFunctor.Test∷Either.Right" == m["$ctor"] then
        return Golden_DerivedFunctor_Test_Right(f(m.value0))
      else
        return error("No patterns matched")
      end
    end
  end
}
local Golden_DerivedFunctor_Test_fromRight_S_w = function(fallback, v)
  if "Golden.DerivedFunctor.Test∷Either.Left" == v["$ctor"] then
    return fallback
  elseif "Golden.DerivedFunctor.Test∷Either.Right" == v["$ctor"] then
    return v.value0
  else
    return error("No patterns matched")
  end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_fromRight_S_w(0, Golden_DerivedFunctor_Test_Right(42))))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_fromRight_S_w(7, Golden_DerivedFunctor_Test_Left("no"))))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_DerivedFunctor_Test_sumTree(Golden_DerivedFunctor_Test_functorTree.map(function( v1_S_2 )
    return v1_S_2 * 2
  end)(Golden_DerivedFunctor_Test_Node(Golden_DerivedFunctor_Test_Node(Golden_DerivedFunctor_Test_Leaf)(1)(Golden_DerivedFunctor_Test_Leaf))(2)(Golden_DerivedFunctor_Test_Node(Golden_DerivedFunctor_Test_Leaf)(3)(Golden_DerivedFunctor_Test_Leaf))))))()
end)()
