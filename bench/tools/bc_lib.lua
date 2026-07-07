-- Shared LuaJIT bytecode introspection for the counter tools: opcode names
-- from jit.vmdef and a prototype walk shaped like jit/bc.lua's — iterate
-- jit.util.funcbc until nil, recurse into child prototypes via negative
-- jit.util.funck indices. The walk starts at pc 0, the FUNC* header slot,
-- so visitors see function-entry opcodes (their J*/I* rewrites are how
-- trace installation and blacklisting are observed).
local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local band = require("bit").band

local M = {}

-- vmdef.bcnames is a string of fixed-width 6-character cells, one per
-- opcode number.
function M.bcname(op)
  return (vmdef.bcnames:sub(op * 6 + 1, op * 6 + 6):gsub("%s+$", ""))
end

function M.basename(source)
  return (source:gsub("^@", ""):gsub("^.*/", ""))
end

-- Depth-first over proto and its children, calling visit(proto, pc, op,
-- depth) for every bytecode. Depth 0 is the outermost (main-chunk)
-- prototype; everything below it is a function body.
function M.walk(proto, visit, depth)
  depth = depth or 0
  local pc = 0
  while true do
    local ins = jutil.funcbc(proto, pc)
    if not ins then
      break
    end
    visit(proto, pc, M.bcname(band(ins, 0xff)), depth)
    pc = pc + 1
  end
  if jutil.funcinfo(proto).children then
    for n = -1, -1e9, -1 do
      local k = jutil.funck(proto, n)
      if not k then
        break
      end
      if type(k) == "proto" then
        M.walk(k, visit, depth + 1)
      end
    end
  end
end

return M
