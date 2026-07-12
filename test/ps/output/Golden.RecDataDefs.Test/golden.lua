local Golden_RecDataDefs_Test_A = { "Golden.RecDataDefs.Test∷A.A" }
local Golden_RecDataDefs_Test_AB = function(value0)
  return { "Golden.RecDataDefs.Test∷A.AB", value0 }
end
local Golden_RecDataDefs_Test_B = { "Golden.RecDataDefs.Test∷B.B" }
local Golden_RecDataDefs_Test_BA = function(value0)
  return { "Golden.RecDataDefs.Test∷B.BA", value0 }
end
local Golden_RecDataDefs_Test_ab = Golden_RecDataDefs_Test_AB(Golden_RecDataDefs_Test_B)
return {
  A = Golden_RecDataDefs_Test_A,
  AB = Golden_RecDataDefs_Test_AB,
  B = Golden_RecDataDefs_Test_B,
  BA = Golden_RecDataDefs_Test_BA,
  a = Golden_RecDataDefs_Test_A,
  b = Golden_RecDataDefs_Test_B,
  ab = Golden_RecDataDefs_Test_ab,
  ba = Golden_RecDataDefs_Test_BA(Golden_RecDataDefs_Test_ab)
}
