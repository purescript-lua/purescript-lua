local Golden_DirectivesFile_M1_keep = function(x) return x + 2 end
return {
  inlined = 5,
  kept = Golden_DirectivesFile_M1_keep(1) + Golden_DirectivesFile_M1_keep(2)
}
