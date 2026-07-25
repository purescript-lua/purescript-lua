### Added

- Loopification now covers mutual recursion and join points (#234), the two
  shapes #181 left as calls. The members of a recursive group's mutual
  tail-call cycle lower to one `while true do` dispatcher over a branch
  selector plus shared argument slots — every transition, sibling or self, is
  one simultaneous multiple assignment — while the member bindings survive as
  entry wrappers, so non-tail uses, the curried wrappers left in the group by
  uncurrying, and external callers keep working unchanged. A chunk-local
  helper only ever tail-called from the enclosing body (a `where`-bound `go`,
  a shared continuation) loses its function shell entirely: its parameters
  hoist as locals, each entry call becomes an assignment falling through into
  the helper's body — an already-loopified worker's entries fall straight
  into its loop, and chains of such helpers flatten one round at a time.
  Under LuaJIT the dispatcher is the shape the trace compiler wants: the new
  `mutual_step` macrobenchmark trace-compiles to parity with hand-written Lua
  (~21x over the cross-calling shape), and join-point fusion brings
  `curried_step`'s per-iteration closure allocations to zero. Under PUC the
  dispatcher trades tail-call machinery for a selector test and per-branch
  parameter rebinds, a small constant-factor regression on pure transition
  loops that substituting slot names for parameters would remove.
