-- Times one macrobenchmark spec: the linked pslua artifact (loaded from
-- bench/_build/, produced by bench/link) against the spec's hand-written
-- idiomatic-Lua equivalent.
--
-- usage: lua|luajit [-joff] run_macro.lua <bench/macro/NAME.lua> [n] [samples]
local here = arg[0]:match("^(.*)/[^/]+$") or "."
local lib = dofile(here .. "/bench_lib.lua")

local spec_path = assert(arg[1], "usage: run_macro.lua <macro.lua> [n] [samples]")
local spec = dofile(spec_path)
local mod = dofile(here .. "/../_build/" .. spec.artifact .. ".lua")
local n = tonumber(arg[2]) or spec.n
local samples = tonumber(arg[3])

local linked = function(k)
  return spec.drive(mod, k)
end
lib.report(spec.name, "linked", n, lib.measure(linked, n, samples))
lib.report(spec.name, "ideal", n, lib.measure(spec.ideal, n, samples))
