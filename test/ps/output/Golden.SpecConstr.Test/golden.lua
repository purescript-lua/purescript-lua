local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Show_showInt = { show = Data_Show_showIntImpl }
local Data_Tuple_append_S_w = function(s1_S_403, s2_S_404)
  return s1_S_403 .. s2_S_404
end
local Data_Tuple_Tuple_S_w = function(value0, value1)
  return { value0, value1 }
end
local Effect_Console_logShow_S_w = function(dictShow, a)
  return Effect_Console_foreign.log(dictShow.show(a))
end
local Golden_SpecConstr_Test_sub_S_w = function(x_S_398, y_S_399)
  return x_S_398 - y_S_399
end
M.Golden_SpecConstr_Test_sumCount = function(n)
  local go
  go = function(acc)
    while true do
      local _S_cse443 = acc[2]
      if _S_cse443 < n then
        acc = Data_Tuple_Tuple_S_w(acc[1] + _S_cse443, _S_cse443 + 1)
      else
        return acc
      end
    end
  end
  return go(Data_Tuple_Tuple_S_w(0, 0))
end
local Golden_SpecConstr_Test_stepDown = function(m)
  while true do
    local _S_cse445 = m[2]
    local _S_cse444 = m[1]
    if "Data.Maybe∷Maybe.Nothing" == _S_cse444 then
      return 0
    elseif "Data.Maybe∷Maybe.Just" == _S_cse444 then
      if _S_cse445 == 0 then
        return 42
      else
        m = {
          "Data.Maybe∷Maybe.Just",
          (Golden_SpecConstr_Test_sub_S_w(_S_cse445, 1))
        }
      end
    else
      return error("No patterns matched")
    end
  end
end
local Golden_SpecConstr_Test_ping
local Golden_SpecConstr_Test_pong = function(t)
  local _S_cse447 = t[2]
  local _S_cse446 = t[1]
  if _S_cse446 == 0 then
    return _S_cse447
  else
    return Golden_SpecConstr_Test_ping(Data_Tuple_Tuple_S_w(Golden_SpecConstr_Test_sub_S_w(_S_cse446, 1), _S_cse447 + 2))
  end
end
Golden_SpecConstr_Test_ping = function(t)
  local _S_cse449 = t[2]
  local _S_cse448 = t[1]
  if _S_cse448 == 0 then
    return _S_cse449
  else
    return Golden_SpecConstr_Test_pong(Data_Tuple_Tuple_S_w(Golden_SpecConstr_Test_sub_S_w(_S_cse448, 1), _S_cse449 + 1))
  end
end
local Golden_SpecConstr_Test_blind_S_w
Golden_SpecConstr_Test_blind_S_w = function(n)
  if n == 0 then
    return 0
  else
    return Golden_SpecConstr_Test_blind_S_w(Golden_SpecConstr_Test_sub_S_w(n, 1), Data_Tuple_Tuple_S_w(n, n))
  end
end
M.Golden_SpecConstr_Test_blind = function(blind_S_p1)
  return function(blind_S_p2)
    return Golden_SpecConstr_Test_blind_S_w(blind_S_p1, blind_S_p2)
  end
end
return (function()
  local _ = Effect_Console_logShow_S_w({
    show = function(v_S_86)
      return Data_Tuple_append_S_w("(Tuple ", Data_Tuple_append_S_w(Data_Show_showIntImpl(v_S_86[1]), Data_Tuple_append_S_w(" ", Data_Tuple_append_S_w(Data_Show_showIntImpl(v_S_86[2]), ")"))))
    end
  }, (function()
    local go_S_432
    go_S_432 = function(acc_S_433)
      while true do
        local _S_cse450 = acc_S_433[2]
        if _S_cse450 < 5 then
          acc_S_433 = Data_Tuple_Tuple_S_w(acc_S_433[1] + _S_cse450, _S_cse450 + 1)
        else
          return acc_S_433
        end
      end
    end
    return go_S_432(Data_Tuple_Tuple_S_w(0, 0))
  end)())()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_SpecConstr_Test_stepDown({
    "Data.Maybe∷Maybe.Just",
    3
  }))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_SpecConstr_Test_stepDown({
    "Data.Maybe∷Maybe.Nothing"
  }))()
  local _ = Effect_Console_logShow_S_w(Data_Show_showInt, Golden_SpecConstr_Test_ping(Data_Tuple_Tuple_S_w(4, 10)))()
  return Effect_Console_logShow_S_w(Data_Show_showInt, Golden_SpecConstr_Test_blind_S_w(3, Data_Tuple_Tuple_S_w(1, 1)))()
end)()
