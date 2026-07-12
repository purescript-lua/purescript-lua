local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
return Effect_Console_foreign.log("\27[31mred\27[0m")()
