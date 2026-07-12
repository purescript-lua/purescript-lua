local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Effect_foreign = {
  pureE = function(a) return function() return a end end
}
return { main = Effect_foreign.pureE(Data_Unit_unit) }
