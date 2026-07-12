local Golden_Newtype_Test_NT = function(x) return x end
return {
  NT = Golden_Newtype_Test_NT,
  f = function(v_S_0) return v_S_0.foo end,
  g = Golden_Newtype_Test_NT
}
