local M = {}
M.Golden_Newtype_Test_NT = function(x) return x end
return {
  NT = M.Golden_Newtype_Test_NT,
  f = function(v_S_0) return v_S_0.foo end,
  g = M.Golden_Newtype_Test_NT
}
