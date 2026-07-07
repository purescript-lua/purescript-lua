-- Shared timing helpers for the wall-clock benchmark runners.
--
-- os.clock() measures CPU time, not wall time. For these CPU-bound loops
-- that is the right metric (time the process spends scheduled out does not
-- pollute samples), but it would silently under-report anything I/O-bound.
-- luacheck: read globals jit
local M = {}

-- Runs fn(n) once untimed (lets LuaJIT compile traces: a loop becomes a
-- tracing candidate after 56 iterations, a side exit after 10), then times
-- `samples` runs with the collector stopped, starting each sample from a
-- freshly collected heap. Reports the median so a stray outlier sample
-- cannot move the headline number.
function M.measure(fn, n, samples)
  samples = samples or 5
  assert(samples >= 1, "samples must be >= 1")
  local checksum = fn(n)
  local times = {}
  for s = 1, samples do
    collectgarbage("collect")
    collectgarbage("stop")
    local t0 = os.clock()
    fn(n)
    local t1 = os.clock()
    collectgarbage("restart")
    times[s] = t1 - t0
  end
  table.sort(times)
  local mid = math.floor((#times + 1) / 2)
  local median = times[mid]
  if #times % 2 == 0 then
    median = (times[mid] + times[mid + 1]) / 2
  end
  return {
    median = median,
    min = times[1],
    max = times[#times],
    checksum = checksum,
  }
end

function M.runtime_tag()
  if jit then
    return jit.status() and "luajit" or "luajit-joff"
  end
  return (_VERSION:gsub("%s", ""):lower())
end

function M.report(bench_name, variant_name, n, r)
  io.write(string.format(
    "%-13s %-8s %-12s n=%-9.0f median=%8.4fs min=%8.4fs max=%8.4fs result=%s\n",
    bench_name,
    variant_name,
    M.runtime_tag(),
    n,
    r.median,
    r.min,
    r.max,
    tostring(r.checksum)
  ))
end

return M
