### Added

- Module-table field reads used repeatedly within one function activation
  are cached in locals at function entry (#174, stage 1): `M.f` reads that
  occur twice on the body's unconditional spine — or once inside a loop,
  where they re-execute per iteration — become reads of an entry local
  (`local Data_Array_index = M.Data_Array_index`), the classic "localize"
  optimization from LuaJIT performance guides. Reads inside conditional
  branches don't qualify on their own (hoisting them taxed leaf-heavy
  recursion by ~25%), but are rewritten once a field qualifies otherwise.
  Reads inside immediately-invoked scope wrappers count toward the
  enclosing function; reads inside real nested closures are left to the
  closure's own caching, so no read moves across an activation boundary
  and the runtime-lazy initialization order is preserved. The pass
  is budget-aware by construction — at most 30 caches per function, with
  ceilings against Lua 5.1's 200-local and 60-upvalue limits (the limits
  that originally forced the `M` table, #19) — and degrades to today's
  plain `M.field` output on any overflow or when hand-written FFI does
  anything to `M` beyond reading fields. Decision recorded in ADR 0001
  (`docs/adr/0001-top-level-binding-storage.md`), the repo's first ADR,
  which also designs stage 2 (budget-aware chunk locals).
