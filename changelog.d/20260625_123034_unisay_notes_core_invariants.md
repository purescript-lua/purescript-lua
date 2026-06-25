### Changed

- Documented three load-bearing compiler invariants as GHC-style `Note`s, each
  cited from its dependent sites: `Note [PSString is UTF-16 code units, not
  text]` (the lone-surrogate invariant, the dual JSON encoding, and the
  decode-or-escape path into Lua), `Note [The PSLUA_runtime_lazy coupling]` (the
  bare string that ties the laziness transform, the Lua fixture, the usage scan,
  and the emit gate together), and `Note [Graph-based dead code elimination for
  Lua]` (an overview of the keying, graph, reachability, and pruning steps).
  Comments only; no change to generated code. First batch of #44.
