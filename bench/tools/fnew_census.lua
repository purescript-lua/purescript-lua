-- Static FNEW census over a Lua chunk: counts closure-creation bytecodes
-- without executing anything, so the output is a pure function of the file.
--
-- An FNEW in the main chunk runs once, at load time; an FNEW in a function
-- body runs on every call of that function, and aborts LuaJIT trace
-- recording (closure creation is NYI in the 2.1 tracer). The split is a
-- structural property of the prototype an instruction lives in: the main
-- chunk is the outermost prototype, everything reachable through child
-- prototypes is a function body. Prototypes are walked the way jit/bc.lua
-- does: iterate jit.util.funcbc until nil, recurse into children via
-- negative jit.util.funck indices.
--
-- usage: luajit fnew_census.lua <chunk.lua>
local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local band = require("bit").band

local function bcname(op)
  return (vmdef.bcnames:sub(op * 6 + 1, op * 6 + 6):gsub("%s+$", ""))
end

local function basename(source)
  return (source:gsub("^@", ""):gsub("^.*/", ""))
end

local counts = { main = 0, body = 0, protos = 0 }
local body_sites = {}

local function walk(proto, in_main)
  counts.protos = counts.protos + 1
  local pc = 1
  while true do
    local ins = jutil.funcbc(proto, pc)
    if not ins then
      break
    end
    if bcname(band(ins, 0xff)) == "FNEW" then
      if in_main then
        counts.main = counts.main + 1
      else
        counts.body = counts.body + 1
        local info = jutil.funcinfo(proto, pc)
        body_sites[#body_sites + 1] =
          string.format("%s:%d", basename(info.source), info.currentline)
      end
    end
    pc = pc + 1
  end
  if jutil.funcinfo(proto).children then
    for n = -1, -1e9, -1 do
      local k = jutil.funck(proto, n)
      if not k then
        break
      end
      if type(k) == "proto" then
        walk(k, false)
      end
    end
  end
end

local path = assert(arg[1], "usage: fnew_census.lua <chunk.lua>")
local chunk = assert(loadfile(path))
walk(chunk, true)

io.write("chunk: ", basename("@" .. path), "\n")
io.write("main-chunk FNEW: ", counts.main, "\n")
io.write("function-body FNEW: ", counts.body, "\n")
io.write("total FNEW: ", counts.main + counts.body, "\n")
io.write("prototypes: ", counts.protos, "\n")
io.write("function-body FNEW sites:\n")
for _, site in ipairs(body_sites) do
  io.write("  ", site, "\n")
end
