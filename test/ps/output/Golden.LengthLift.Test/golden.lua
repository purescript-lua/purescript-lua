local M = {}
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
local Control_Monad_ST_Internal_foreign = {
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end
}
local Data_Array_ST_foreign = (function()
  -- Lua 5.1 has no table.move, so provide an overlap-safe equivalent with the
  -- same semantics as Lua 5.3's table.move(a1, f, e, t, a2): copy a1[f..e] to
  -- a2 starting at t, iterating backwards when the source and destination overlap
  -- so a forward shift to the right does not clobber elements before reading them.
  local function move(a1, f, e, t, a2)
    a2 = a2 or a1
    if e >= f then
      if a1 ~= a2 or t <= f or t > e then
        for i = 0, e - f do a2[t + i] = a1[f + i] end
      else
        for i = e - f, 0, -(1) do a2[t + i] = a1[f + i] end
      end
    end
    return a2
  end
  local function copyImpl(xs) return move(xs, 1, #(xs), 1, {}) end
  return {
    lengthImpl = function(xs) return #(xs) end,
    thawImpl = copyImpl,
    pushImpl = function(a, xs) xs[#(xs) + 1] = a return #(xs) end
  }
end)()
local Data_Array_ST_lengthImpl = Data_Array_ST_foreign.lengthImpl
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
M.Golden_LengthLift_Test_widthOf = function(s_S_0) return #(s_S_0) end
local Golden_LengthLift_Test_lengthsAroundPush = Control_Monad_ST_Internal_foreign.run(function(  )
  local arr = Data_Array_ST_foreign.thawImpl({ [1] = 1, [2] = 2, [3] = 3 })
  local before = Data_Array_ST_lengthImpl(arr)
  local _ = Data_Array_ST_foreign.pushImpl(4, arr)
  local after = Data_Array_ST_lengthImpl(arr)
  return { [1] = before, [2] = after }
end)
M.Golden_LengthLift_Test_countOf = function(xs_S_0) return #(xs_S_0) end
M.Golden_LengthLift_Test_countBelow = function(xs)
  local acc, i
  acc, i = 0, 0
  while true do
    if i < #(xs) then acc, i = acc + i, i + 1 else return acc end
  end
end
return (function()
  local _ = Effect_Console_log(Data_Show_showIntImpl(3))()
  local _ = Effect_Console_log(Data_Show_showIntImpl(#("hello")))()
  local _ = Effect_Console_log(Data_Show_showIntImpl((function()
    local acc_S_0, i_S_0
    acc_S_0, i_S_0 = 0, 0
    while true do
      if i_S_0 < 4 then
        acc_S_0, i_S_0 = acc_S_0 + i_S_0, i_S_0 + 1
      else
        return acc_S_0
      end
    end
  end)()))()
  return Effect_Console_log(Data_Show_foreign.showArrayImpl(Data_Show_showIntImpl)(Golden_LengthLift_Test_lengthsAroundPush))()
end)()
