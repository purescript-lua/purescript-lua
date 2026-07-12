local Golden_Foreign_Lib_foreign = { alive = 100 }
local Golden_Foreign_Test_foreign = (function()
  local fooBar = 42
  return { foo = fooBar + 1, boo = fooBar + 2 }
end)()
return {
  foo = Golden_Foreign_Test_foreign.foo,
  baz = {
    [1] = Golden_Foreign_Test_foreign.boo,
    [2] = Golden_Foreign_Lib_foreign.alive
  }
}
