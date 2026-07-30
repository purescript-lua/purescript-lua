local M = {}
local Data_Show_showIntImpl = function(n) return tostring(n) end
local Effect_Console_log = function(s) return function() print(s) end end
local Golden_EffectWorkerThunk_Test_tally_S_w = function(tag, n)
  local _ = Effect_Console_log(tag)()
  local _ = Effect_Console_log(Data_Show_showIntImpl(n * 2))()
  return Effect_Console_log("=")()
end
M.Golden_EffectWorkerThunk_Test_tally = function(tally_S_p1)
  return function(tally_S_p2)
    return function(tally_S_p2_S_t)
      return Golden_EffectWorkerThunk_Test_tally_S_w(tally_S_p1, tally_S_p2, tally_S_p2_S_t)
    end
  end
end
M.Golden_EffectWorkerThunk_Test_runWith = function(f)
  return function()
    local _ = f("via")(3)()
    return Effect_Console_log("ran")()
  end
end
local Golden_EffectWorkerThunk_Test_report_S_w = function(tag, n)
  local _ = Effect_Console_log(tag)()
  local _ = Effect_Console_log(Data_Show_showIntImpl(n))()
  return Effect_Console_log("-")()
end
local Golden_EffectWorkerThunk_Test_deferred_S_w = function(tag, n)
  return function()
    local _ = Effect_Console_log(tag)()
    local _ = Effect_Console_log(Data_Show_showIntImpl(n + 100))()
    return Effect_Console_log("+")()
  end
end
return (function()
  local _ = Golden_EffectWorkerThunk_Test_report_S_w("a", 1)
  local _ = Golden_EffectWorkerThunk_Test_report_S_w("b", 2)
  local _ = Golden_EffectWorkerThunk_Test_tally_S_w("c", 3)
  local _ = (function()
    local _ = Golden_EffectWorkerThunk_Test_tally_S_w("via", 3)
    return Effect_Console_log("ran")()
  end)()
  local step_S_0_S_w = function(a_S_0, b_S_0)
    local _ = Effect_Console_log(a_S_0)()
    local _ = Effect_Console_log(Data_Show_showIntImpl(b_S_0 * 10))()
    return Effect_Console_log("*")()
  end
  local _ = step_S_0_S_w("e", 5)
  local _ = step_S_0_S_w("f", 6)
  local held_S_0 = Golden_EffectWorkerThunk_Test_deferred_S_w("d", 4)
  local _ = Effect_Console_log("before held")()
  local _ = held_S_0()
  return held_S_0()
end)()
