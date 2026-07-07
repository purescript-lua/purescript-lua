-- Runs a macrobenchmark spec hot under the tracing JIT and reports two
-- deterministic signals per source location:
--
--   * the set of distinct trace-abort sites (location + reason), collected
--     via jit.attach("trace"). A set, not a count: how many retries happen
--     before a spot is blacklisted depends on LuaJIT's entropy-seeded
--     penalty PRNG, so raw abort counts are not stable across runs.
--
--   * the end state of loop and function-entry bytecodes after the run,
--     read back with jit.util.funcbc: the JIT rewrites an opcode to its J*
--     form when it installs a trace there and to its I* form when it
--     blacklists the spot. Blacklisting itself is never logged, so this
--     post-hoc read is the only stable way to observe it.
--
-- usage: luajit trace_report.lua <bench/macro/NAME.lua>
-- luacheck: read globals jit
local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local here = arg[0]:match("^(.*)/[^/]+$") or "."
local bc = dofile(here .. "/bc_lib.lua")

local function location(func, pc)
  local info = jutil.funcinfo(func, pc)
  return bc.basename(info.source), info.currentline or 0
end

-- The J*/I* rewrite families, derived from vmdef.bcnames so a LuaJIT bump
-- that adds a hot-countable pair shows up instead of being silently
-- skipped: an opcode named J<X> or I<X> where X is itself an opcode is a
-- rewrite form of X. (FORI has a J form only — the trace entry at a loop
-- start; the I* fallbacks exist for hot-countable spots: loops and
-- function entries.)
local COMPILED, BLACKLISTED = {}, {}
do
  local names = {}
  for op = 0, #vmdef.bcnames / 6 - 1 do
    names[bc.bcname(op)] = true
  end
  for name in pairs(names) do
    local prefix, base = name:sub(1, 1), name:sub(2)
    if names[base] then
      if prefix == "J" then
        COMPILED[name] = true
      elseif prefix == "I" then
        BLACKLISTED[name] = true
      end
    end
  end
end

local spec_path = assert(arg[1], "usage: trace_report.lua <macro.lua>")
local spec_name = spec_path:match("([^/]+)%.lua$")
local spec_chunk = assert(loadfile(spec_path))
local spec = spec_chunk()
local artifact_path = here .. "/../_build/" .. spec.artifact .. ".lua"
local artifact_chunk = assert(loadfile(artifact_path))
local mod = artifact_chunk()

local aborts = {}
local function on_trace(what, _tr, func, pc, code, extra)
  if what ~= "abort" then
    return
  end
  local reason = code
  if type(code) == "number" then
    local msg = vmdef.traceerr[code] or ("trace error " .. code)
    -- Whether recording ever runs into an already-blacklisted spot depends
    -- on how many PRNG-jittered retries preceded the blacklist, so this
    -- abort reason is not stable across runs. It carries no information of
    -- its own either: the blacklisted spot shows up as an I* opcode below.
    if msg == "blacklisted" then
      return
    end
    if type(extra) == "number" and msg:find("bytecode") then
      extra = bc.bcname(extra)
    elseif type(extra) == "function" then
      -- Builtins carry no source (funcinfo gives ffid/addr instead), so
      -- fall back the way jit/dump.lua's fmtfunc does.
      local info = jutil.funcinfo(extra)
      if info.source then
        local file, line = location(extra)
        extra = file .. ":" .. line
      elseif info.ffid then
        extra = vmdef.ffnames[info.ffid]
      elseif info.addr then
        extra = string.format("C:%x", info.addr)
      else
        extra = "(?)"
      end
    end
    reason = msg:find("%%") and string.format(msg, extra) or msg
  end
  local file, line = location(func, pc)
  aborts[string.format("%s:%d -- %s", file, line, reason)] = true
end

jit.attach(on_trace, "trace")
local checksum
for _ = 1, 2 do
  checksum = spec.drive(mod, spec.n)
  spec.ideal(spec.n)
end
jit.attach(on_trace)

local states = {}
local function visit(proto, pc, op)
  if COMPILED[op] or BLACKLISTED[op] then
    local file, line = location(proto, pc)
    states[string.format("%s:%d %s", file, line, op)] = op
  end
end
bc.walk(artifact_chunk, visit)
bc.walk(spec_chunk, visit)

local function sorted_keys(set)
  local keys = {}
  for key in pairs(set) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

io.write("spec: ", spec_name, "\n")
io.write("runtime: ", jit.version, "\n")
io.write(string.format("workload: n=%.0f reps=2 result=%s\n", spec.n, tostring(checksum)))
io.write("aborts (distinct site -- reason):\n")
local abort_keys = sorted_keys(aborts)
for _, key in ipairs(abort_keys) do
  io.write("  ", key, "\n")
end
local compiled, blacklisted = 0, 0
local state_keys = sorted_keys(states)
io.write("bytecode end state (J*=compiled, I*=blacklisted):\n")
for _, key in ipairs(state_keys) do
  if COMPILED[states[key]] then
    compiled = compiled + 1
  else
    blacklisted = blacklisted + 1
  end
  io.write("  ", key, "\n")
end
io.write(string.format(
  "counts: aborts=%d compiled=%d blacklisted=%d\n",
  #abort_keys,
  compiled,
  blacklisted
))
