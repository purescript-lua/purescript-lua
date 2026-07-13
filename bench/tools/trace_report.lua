-- Runs a macrobenchmark spec hot under the tracing JIT and reports two
-- signals per source location:
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
-- Both signals are canonicalized across independent trials by majority
-- vote: a site or an end state is reported when more than half the trials
-- observe it. LuaJIT's hot-counters live in a small hashed table keyed by
-- bytecode address, and the retry penalty draws on an entropy-seeded PRNG,
-- so a spot sitting right at the hot-count boundary -- e.g. an export
-- wrapper's entry whose root trace completes in most processes but not
-- all -- forms a trace with some per-process probability p. Decisive
-- spots (hot loops, blacklisted entries, reliably root-traced workers)
-- have p at 0 or 1, and the vote reports them exactly as any rule would;
-- the vote exists for the marginal ones, where its misreport odds decay
-- binomially in the trial count for any p away from one half. A unanimity
-- rule has no such zone of stability near p = 1: the Bench.BindChain run
-- wrapper measures p ~ 0.9 (present in 27 of 30 trials), which unanimity
-- turns into a ~0.9^9 coin flip per report, with no pinnable golden on
-- either side. Note that p belongs to the whole process layout, not the
-- spot alone: even the length of the artifact's chunk-name string shifts
-- allocation addresses enough to move counter aliasing -- the same
-- artifact measures p ~ 0.05 when loaded through a shorter relative path.
-- ./bench/ci runs everything from the repository root, so the goldens pin
-- the counters for that layout. The canonical report is stable by
-- construction, so ./bench/ci verifies each report once.
--
-- usage:
--   luajit trace_report.lua <bench/macro/NAME.lua>          canonical report
--   luajit trace_report.lua <bench/macro/NAME.lua> --trial  one raw trial
-- The trial count defaults to 9 and can be overridden with the environment
-- variable BENCH_TRACE_TRIALS (mainly to reproduce the raw flake with 1).
-- Keep it odd: a strict majority cannot tie.
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
-- rewrite form of X. (FORI has a J form only -- the trace entry at a loop
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

-- How many times the workload runs per trial. The spec's drive and ideal
-- entries are called exactly this many times, and the eager hot-call
-- threshold below fires at two calls, so reps must exceed two with slack:
-- at reps = 2 those entries sit exactly on the threshold and whether they
-- (and the abort sites their first trace records) resolve is a race.
local reps = 4

-- One trial: drive the spec hot and return its measured signals.
local function measure(spec_path)
  -- Eager hot thresholds: with the default (56/112 undecayed bumps) a
  -- counter must accumulate, and LuaJIT's hot-counters live in a small
  -- hashed table keyed by bytecode address, so whether a spot ever fires
  -- can hinge on a per-process address dice roll (a colliding hotter
  -- counter decays the victim's forever). At threshold 1 a spot fires on
  -- its first bumps, before any collision can decay it, so every
  -- hot-countable spot resolves to a decisive end state: a traceable body
  -- completes its first trace (J*), an untraceable one aborts through its
  -- penalty ladder and blacklists (I*). The report measures which bytecode
  -- shapes can trace, not warmup timing, so eager firing loses nothing.
  jit.opt.start("hotloop=1")
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
  for _ = 1, reps do
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

  return {
    spec = spec_name,
    runtime = jit.version,
    workload = string.format(
      "n=%.0f reps=%d result=%s",
      spec.n,
      reps,
      tostring(checksum)
    ),
    aborts = aborts,
    states = states,
  }
end

local function sorted_keys(set)
  local keys = {}
  for key in pairs(set) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function print_report(report)
  io.write("spec: ", report.spec, "\n")
  io.write("runtime: ", report.runtime, "\n")
  io.write("workload: ", report.workload, "\n")
  io.write("aborts (distinct site -- reason):\n")
  local abort_keys = sorted_keys(report.aborts)
  for _, key in ipairs(abort_keys) do
    io.write("  ", key, "\n")
  end
  local compiled, blacklisted = 0, 0
  local state_keys = sorted_keys(report.states)
  io.write("bytecode end state (J*=compiled, I*=blacklisted):\n")
  for _, key in ipairs(state_keys) do
    -- The op is the last token of the key; classify by its J*/I* family.
    if COMPILED[report.states[key]] then
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
end

local spec_path = assert(arg[1], "usage: trace_report.lua <macro.lua> [--trial]")

-- A single trial prints its own report. This is the raw, per-process view:
-- run it a few times and you will see marginal spots flicker in and out.
if arg[2] == "--trial" then
  print_report(measure(spec_path))
  return
end

-- Canonical mode: majority vote over the signals of N independent trials.
-- Each trial is a fresh luajit process, since bytecode rewrites and the
-- JIT's PRNG state persist for the life of a process -- looping in-process
-- would just re-read the first trial's end state. Reading each trial's
-- report back keeps the report format in one place (print_report) instead
-- of splitting it between the tool and the shell harness.
local trials = tonumber(os.getenv("BENCH_TRACE_TRIALS")) or 9
if trials < 1 then
  trials = 1
end

local function parse_report(text)
  local report = { aborts = {}, states = {} }
  local section
  for line in text:gmatch("[^\n]+") do
    if line == "aborts (distinct site -- reason):" then
      section = "aborts"
    elseif line:match("^bytecode end state") then
      section = "states"
    elseif line:match("^counts:") then
      section = nil
    elseif line:match("^  ") then
      local item = line:sub(3)
      if section == "aborts" then
        report.aborts[item] = true
      elseif section == "states" then
        report.states[item] = item:match("(%S+)$")
      end
    else
      local key, value = line:match("^(%w+): (.*)$")
      if key == "spec" then
        report.spec = value
      elseif key == "runtime" then
        report.runtime = value
      elseif key == "workload" then
        report.workload = value
      end
    end
  end
  return report
end

local function run_trial(index)
  local command = string.format('luajit "%s" "%s" --trial', arg[0], spec_path)
  local handle = assert(io.popen(command, "r"))
  local text = handle:read("*a")
  if not handle:close() then
    io.stderr:write(string.format("trace_report: trial %d failed\n", index))
    os.exit(1)
  end
  return parse_report(text)
end

-- Tally how often each item shows up across trials; 'values' remembers
-- the item's mapped value (the opcode for states, 'true' for aborts).
local function tally(votes, values, items)
  for key, value in pairs(items) do
    votes[key] = (votes[key] or 0) + 1
    values[key] = value
  end
end

-- Keep the items a strict majority of trials agree on.
local function elect(votes, values)
  local elected = {}
  for key, count in pairs(votes) do
    if 2 * count > trials then
      elected[key] = values[key]
    end
  end
  return elected
end

local canonical
local abortVotes, abortValues = {}, {}
local stateVotes, stateValues = {}, {}
for index = 1, trials do
  local trial = run_trial(index)
  if not canonical then
    canonical = trial
  else
    -- The header is derived from the spec and a deterministic checksum, so a
    -- divergence here is a real bug (e.g. a nondeterministic result), not
    -- trace-formation noise -- surface it instead of silently out-voting it.
    if
      trial.spec ~= canonical.spec
      or trial.runtime ~= canonical.runtime
      or trial.workload ~= canonical.workload
    then
      io.stderr:write(string.format(
        "trace_report: trial %d header diverged (spec/runtime/workload)\n",
        index
      ))
      os.exit(1)
    end
  end
  tally(abortVotes, abortValues, trial.aborts)
  tally(stateVotes, stateValues, trial.states)
end
canonical.aborts = elect(abortVotes, abortValues)
canonical.states = elect(stateVotes, stateValues)
print_report(canonical)
