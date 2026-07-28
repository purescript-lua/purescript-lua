local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Data_Show_showIntImpl = Data_Show_foreign.showIntImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_SpecConstr_Test_sumCount = function(n)
  local go_S_sc1Tuple_S_f1, go_S_sc1Tuple_S_f2
  go_S_sc1Tuple_S_f1, go_S_sc1Tuple_S_f2 = 0, 0
  while true do
    if go_S_sc1Tuple_S_f2 < n then
      go_S_sc1Tuple_S_f1, go_S_sc1Tuple_S_f2 = go_S_sc1Tuple_S_f1 + go_S_sc1Tuple_S_f2, go_S_sc1Tuple_S_f2 + 1
    else
      return { go_S_sc1Tuple_S_f1, go_S_sc1Tuple_S_f2 }
    end
  end
end
local Golden_SpecConstr_Test_stepDown_S_sc1Just = function( stepDown_S_sc1Just_S_f1 )
  while true do
    if stepDown_S_sc1Just_S_f1 == 0 then
      return 42
    else
      stepDown_S_sc1Just_S_f1 = stepDown_S_sc1Just_S_f1 - 1
    end
  end
end
local Golden_SpecConstr_Test_stepDown = function(m)
  local _S_cse0 = m[2]
  if "Data.Maybe∷Maybe.Nothing" == m[1] then
    return 0
  elseif _S_cse0 == 0 then
    return 42
  else
    return Golden_SpecConstr_Test_stepDown_S_sc1Just(_S_cse0 - 1)
  end
end
local Golden_SpecConstr_Test_pong_S_sc1Tuple_S_loop = function( _S_sel0
, _S_a0
, _S_a1 )
  while true do
    if _S_sel0 == 1 then
      local pong_S_sc1Tuple_S_f1, pong_S_sc1Tuple_S_f2 = _S_a0, _S_a1
      if pong_S_sc1Tuple_S_f1 == 0 then
        return pong_S_sc1Tuple_S_f2
      else
        _S_sel0, _S_a0, _S_a1 = 2, pong_S_sc1Tuple_S_f1 - 1, pong_S_sc1Tuple_S_f2 + 2
      end
    else
      local ping_S_sc1Tuple_S_f1, ping_S_sc1Tuple_S_f2 = _S_a0, _S_a1
      if ping_S_sc1Tuple_S_f1 == 0 then
        return ping_S_sc1Tuple_S_f2
      else
        _S_sel0, _S_a0, _S_a1 = 1, ping_S_sc1Tuple_S_f1 - 1, ping_S_sc1Tuple_S_f2 + 1
      end
    end
  end
end
local Golden_SpecConstr_Test_pong_S_sc1Tuple = function( pong_S_sc1Tuple_S_f1
, pong_S_sc1Tuple_S_f2 )
  return Golden_SpecConstr_Test_pong_S_sc1Tuple_S_loop(1, pong_S_sc1Tuple_S_f1, pong_S_sc1Tuple_S_f2)
end
local Golden_SpecConstr_Test_ping_S_sc1Tuple
M.Golden_SpecConstr_Test_pong = function(t)
  local _S_cse1 = t[2]
  local _S_cse2 = t[1]
  if _S_cse2 == 0 then
    return _S_cse1
  else
    return Golden_SpecConstr_Test_ping_S_sc1Tuple(_S_cse2 - 1, _S_cse1 + 2)
  end
end
Golden_SpecConstr_Test_ping_S_sc1Tuple = function( ping_S_sc1Tuple_S_f1
, ping_S_sc1Tuple_S_f2 )
  return Golden_SpecConstr_Test_pong_S_sc1Tuple_S_loop(2, ping_S_sc1Tuple_S_f1, ping_S_sc1Tuple_S_f2)
end
M.Golden_SpecConstr_Test_ping = function(t)
  local _S_cse3 = t[2]
  local _S_cse4 = t[1]
  if _S_cse4 == 0 then
    return _S_cse3
  else
    return Golden_SpecConstr_Test_pong_S_sc1Tuple(_S_cse4 - 1, _S_cse3 + 1)
  end
end
local Golden_SpecConstr_Test_blind_S_w
Golden_SpecConstr_Test_blind_S_w = function(n)
  if n == 0 then
    return 0
  else
    return Golden_SpecConstr_Test_blind_S_w(n - 1, { n, n })
  end
end
M.Golden_SpecConstr_Test_blind = function(blind_S_p1)
  return function(blind_S_p2)
    return Golden_SpecConstr_Test_blind_S_w(blind_S_p1, blind_S_p2)
  end
end
return (function()
  local _ = Effect_Console_log((function()
    local v_S_0 = (function()
      local go_S_0_S_sc1Tuple_S_f1, go_S_0_S_sc1Tuple_S_f2
      go_S_0_S_sc1Tuple_S_f1, go_S_0_S_sc1Tuple_S_f2 = 0, 0
      while true do
        if go_S_0_S_sc1Tuple_S_f2 < 5 then
          go_S_0_S_sc1Tuple_S_f1, go_S_0_S_sc1Tuple_S_f2 = go_S_0_S_sc1Tuple_S_f1 + go_S_0_S_sc1Tuple_S_f2, go_S_0_S_sc1Tuple_S_f2 + 1
        else
          return { go_S_0_S_sc1Tuple_S_f1, go_S_0_S_sc1Tuple_S_f2 }
        end
      end
    end)()
    return "(Tuple " .. Data_Show_showIntImpl(v_S_0[1]) .. " " .. Data_Show_showIntImpl(v_S_0[2]) .. ")"
  end)())()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_SpecConstr_Test_stepDown_S_sc1Just(3)))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_SpecConstr_Test_stepDown({
    "Data.Maybe∷Maybe.Nothing"
  })))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(Golden_SpecConstr_Test_ping_S_sc1Tuple(4, 10)))()
  return Effect_Console_log(Data_Show_showIntImpl(Golden_SpecConstr_Test_blind_S_w(3, {
    1,
    1
  })))()
end)()
