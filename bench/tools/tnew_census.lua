-- Static table-allocation census over a Lua chunk: counts the two
-- table-creation bytecodes without executing anything, so the output is a
-- pure function of the file and the LuaJIT version (recorded in the report
-- header). TNEW allocates a fresh (possibly pre-sized) empty table; TDUP
-- clones a constant template table. Both are one table allocation per
-- execution, and a codegen change can convert one into the other, so the
-- report keeps them separate and also sums them.
--
-- A table bytecode in the main chunk runs once, at load time; one in a
-- function body runs on every call of that function. Unlike FNEW, neither
-- aborts LuaJIT trace recording -- allocation cost is invisible to the
-- trace report, which is exactly why this census exists. The split is a
-- structural property of the prototype an instruction lives in: the main
-- chunk is the outermost prototype, everything reachable through child
-- prototypes is a function body.
--
-- usage: luajit tnew_census.lua <chunk.lua>
-- luacheck: read globals jit
local jutil = require("jit.util")
local here = arg[0]:match("^(.*)/[^/]+$") or "."
local bc = dofile(here .. "/bc_lib.lua")

local counts = { main = 0, body = 0, protos = 0 }
local body_sites = {}

local function visit(proto, pc, op, depth)
  if pc == 0 then
    counts.protos = counts.protos + 1
  end
  if op == "TNEW" or op == "TDUP" then
    if depth == 0 then
      counts.main = counts.main + 1
    else
      counts.body = counts.body + 1
      local info = jutil.funcinfo(proto, pc)
      body_sites[#body_sites + 1] = string.format(
        "%s:%d %s",
        bc.basename(info.source),
        info.currentline,
        op
      )
    end
  end
end

local path = assert(arg[1], "usage: tnew_census.lua <chunk.lua>")
local chunk = assert(loadfile(path))
bc.walk(chunk, visit)

io.write("chunk: ", bc.basename("@" .. path), "\n")
io.write("runtime: ", jit.version, "\n")
io.write("main-chunk TNEW+TDUP: ", counts.main, "\n")
io.write("function-body TNEW+TDUP: ", counts.body, "\n")
io.write("total TNEW+TDUP: ", counts.main + counts.body, "\n")
io.write("prototypes: ", counts.protos, "\n")
io.write("function-body TNEW+TDUP sites:\n")
for _, site in ipairs(body_sites) do
  io.write("  ", site, "\n")
end
