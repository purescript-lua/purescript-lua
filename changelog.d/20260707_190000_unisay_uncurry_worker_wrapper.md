### Added

- Functions are uncurried through a worker/wrapper split (#24): every binding
  with a manifest arity of two or more and at least one saturated call site
  becomes an n-ary Lua worker plus a curried wrapper under the original name,
  and the saturated sites call the worker directly — `add(x)(y)` becomes
  `add$w(x, y)`. Partial applications and functions passed as values keep
  going through the wrapper, so behavior is unchanged; unreferenced wrappers
  are removed by dead-code elimination. This removes per-application closure
  allocation on saturated calls — the main LuaJIT trace-compilation unlock,
  since closure creation aborts trace recording. The definition-side `AbsN`
  node mirrors `AppN` (`Abs` is now its singleton pattern synonym), beta
  reduction handles exact-arity n-ary redexes, and the deep-bind flattening
  recognises n-ary chains and spines.
