local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_CasePruning_Test_logShow = function(a_S_0)
  return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(a_S_0))
end
local Golden_CasePruning_Test_A = { "Golden.CasePruning.Test∷T.A" }
local Golden_CasePruning_Test_B = { "Golden.CasePruning.Test∷T.B" }
local Golden_CasePruning_Test_C = { "Golden.CasePruning.Test∷T.C" }
local Golden_CasePruning_Test_literalRetest = function(v)
  return function(v1)
    if 0 == v then if "" == v1 then return 1 else return 2 end else return 3 end
  end
end
local Golden_CasePruning_Test_literalNegatives = function(v)
  return function(v1)
    if 1 == v then
      if 1 == v1 then return 1 elseif 2 == v1 then return 3 else return 4 end
    elseif 2 == v then
      if 2 == v1 then return 2 else return 4 end
    else
      return 4
    end
  end
end
local Golden_CasePruning_Test_ctorRetest = function(v)
  return function(v1)
    local _S_cse0 = v1[1]
    local _S_cse1 = v[1]
    if "Golden.CasePruning.Test∷T.A" == _S_cse1 then
      if "Golden.CasePruning.Test∷T.A" == _S_cse0 then
        return 1
      elseif "Golden.CasePruning.Test∷T.B" == _S_cse0 then
        return 3
      else
        return 4
      end
    elseif "Golden.CasePruning.Test∷T.B" == _S_cse1 then
      if "Golden.CasePruning.Test∷T.B" == _S_cse0 then
        return 2
      else
        return 4
      end
    else
      return 4
    end
  end
end
return (function()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalRetest(0)(""))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalRetest(0)("x"))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalRetest(5)(""))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_ctorRetest(Golden_CasePruning_Test_A)(Golden_CasePruning_Test_A))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_ctorRetest(Golden_CasePruning_Test_B)(Golden_CasePruning_Test_B))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_ctorRetest(Golden_CasePruning_Test_A)(Golden_CasePruning_Test_B))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_ctorRetest(Golden_CasePruning_Test_A)(Golden_CasePruning_Test_C))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_ctorRetest(Golden_CasePruning_Test_C)(Golden_CasePruning_Test_C))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalNegatives(1)(1))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalNegatives(2)(2))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalNegatives(1)(2))()
  local _ = Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalNegatives(1)(3))()
  return Golden_CasePruning_Test_logShow(Golden_CasePruning_Test_literalNegatives(3)(3))()
end)()
