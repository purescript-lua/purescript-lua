-- Static FNEW census over a Lua chunk: counts closure-creation bytecodes
-- without executing anything, so the output is a pure function of the file
-- and the LuaJIT version (recorded in the report header).
--
-- An FNEW in the main chunk runs once, at load time; an FNEW in a function
-- body runs on every call of that function, and aborts LuaJIT trace
-- recording (closure creation is NYI in the 2.1 tracer). The split is a
-- structural property of the prototype an instruction lives in: the main
-- chunk is the outermost prototype, everything reachable through child
-- prototypes is a function body.
--
-- usage: luajit fnew_census.lua <chunk.lua>
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
  if op == "FNEW" then
    if depth == 0 then
      counts.main = counts.main + 1
    else
      counts.body = counts.body + 1
      local info = jutil.funcinfo(proto, pc)
      body_sites[#body_sites + 1] =
        string.format("%s:%d", bc.basename(info.source), info.currentline)
    end
  end
end

local path = assert(arg[1], "usage: fnew_census.lua <chunk.lua>")
local chunk = assert(loadfile(path))
bc.walk(chunk, visit)

io.write("chunk: ", bc.basename("@" .. path), "\n")
io.write("runtime: ", jit.version, "\n")
io.write("main-chunk FNEW: ", counts.main, "\n")
io.write("function-body FNEW: ", counts.body, "\n")
io.write("total FNEW: ", counts.main + counts.body, "\n")
io.write("prototypes: ", counts.protos, "\n")
io.write("function-body FNEW sites:\n")
for _, site in ipairs(body_sites) do
  io.write("  ", site, "\n")
end
