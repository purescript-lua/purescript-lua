local M = {}
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
M.Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_494)
        return function(m_S_495) return f_S_494(m_S_495) end
      end
    }
  end
}
M.Data_Identity_bindIdentity = {
  bind = function(v) return function(f) return f(v) end end,
  Apply0 = function() return M.Data_Identity_applyIdentity end
}
M.Data_Identity_applicativeIdentity = {
  pure = function(x_S_496) return x_S_496 end,
  Apply0 = function() return M.Data_Identity_applyIdentity end
}
M.Golden_LongReaderBind_Test_ask = (function()
  local dictMonad_S_488 = {
    Applicative0 = function() return M.Data_Identity_applicativeIdentity end,
    Bind1 = function() return M.Data_Identity_bindIdentity end
  }
  return (dictMonad_S_488.Applicative0()).pure
end)()
M.Golden_LongReaderBind_Test_add_S_w = function(x_S_469_S_501, y_S_470_S_502)
  return x_S_469_S_501 + y_S_470_S_502
end
M.Golden_LongReaderBind_Test_go = function(r_S_552_S_588)
  local Golden_LongReaderBind_Test_ask, Golden_LongReaderBind_Test_add_S_w = M.Golden_LongReaderBind_Test_ask, M.Golden_LongReaderBind_Test_add_S_w
  return Golden_LongReaderBind_Test_add_S_w(Golden_LongReaderBind_Test_add_S_w(Golden_LongReaderBind_Test_ask(r_S_552_S_588), Golden_LongReaderBind_Test_ask(r_S_552_S_588)), Golden_LongReaderBind_Test_ask(r_S_552_S_588))
end
M.Golden_LongReaderBind_Test_compute = M.Unsafe_Coerce_foreign.unsafeCoerce(M.Golden_LongReaderBind_Test_add_S_w(M.Golden_LongReaderBind_Test_add_S_w(M.Golden_LongReaderBind_Test_ask(3), M.Golden_LongReaderBind_Test_ask(3)), M.Golden_LongReaderBind_Test_ask(3)))
return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(M.Golden_LongReaderBind_Test_compute))()
