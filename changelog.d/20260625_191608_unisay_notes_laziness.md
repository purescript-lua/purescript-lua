### Changed

- Documented the laziness runtime's cross-module contract: `Note [The runtimeLazy
  calling convention]` in the Lua fixture spells out the curried
  `name -> init -> force` shape and why `state`/`val` must live in the closure
  that returns the forcing thunk, and `Note [Laziness transform for recursive
  binding groups]` gives `CoreFn.Laziness` a citable anchor. Corrected two stale
  comments inherited from the upstream JS backend (the factory takes two
  arguments in the Lua port, not three, and the Lua fixture ignores the line
  number). Comments only; no change to generated code. Continues #44.
