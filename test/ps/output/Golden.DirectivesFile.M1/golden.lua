local Golden_DirectivesFile_M1_add_S_w = function(x_S_168_S_188, y_S_169_S_189)
  return x_S_168_S_188 + y_S_169_S_189
end
local Golden_DirectivesFile_M1_keep = function(x)
  return Golden_DirectivesFile_M1_add_S_w(x, 2)
end
local Golden_DirectivesFile_M1_incr = function(x)
  return Golden_DirectivesFile_M1_add_S_w(x, 1)
end
return {
  incr = Golden_DirectivesFile_M1_incr,
  keep = Golden_DirectivesFile_M1_keep
}
