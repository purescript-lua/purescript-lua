-- Times every variant of one microbenchmark under the current runtime.
--
-- usage: lua|luajit [-joff] run_micro.lua <bench/micro/NAME.lua> [n] [samples]
local here = arg[0]:match("^(.*)/[^/]+$") or "."
local lib = dofile(here .. "/bench_lib.lua")

local spec_path = assert(arg[1], "usage: run_micro.lua <micro.lua> [n] [samples]")
local spec = dofile(spec_path)
local n = tonumber(arg[2]) or spec.n
local samples = tonumber(arg[3])

for _, variant in ipairs(spec.variants) do
  lib.report(spec.name, variant.name, n, lib.measure(variant.fn, n, samples))
end
