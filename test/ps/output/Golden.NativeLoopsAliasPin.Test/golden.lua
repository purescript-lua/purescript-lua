local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_foreign = {
  bindE = function(a)
    return function(f) return function() return f(a())() end end
  end,
  forE = function(lo)
    return function(hi)
      return function(f)
        return function() for i = lo, hi - 1 do f(i)() end end
      end
    end
  end
}
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Effect_Console_log = Effect_Console_foreign.log
local Golden_NativeLoopsAliasPin_Test_logShow = function(a_S_0)
  return Effect_Console_log(Data_Show_foreign.showIntImpl(a_S_0))
end
local Golden_NativeLoopsAliasPin_Test_myFor = Effect_foreign.forE
return (function()
  local _ = Effect_Console_log("first:")()
  local _ = Golden_NativeLoopsAliasPin_Test_myFor(1)(3)(Golden_NativeLoopsAliasPin_Test_logShow)()
  local _ = Effect_Console_log("second:")()
  return Golden_NativeLoopsAliasPin_Test_myFor(5)(7)(Golden_NativeLoopsAliasPin_Test_logShow)()
end)()
