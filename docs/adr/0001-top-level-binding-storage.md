# 1. Top-level binding storage

Date: 2026-07-07

## Status

Accepted. Stage 1 (per-function field caching) is implemented; stage 2
(budget-aware two-tier storage) is designed here and tracked in issue
[#174].

[#174]: https://github.com/purescript-lua/purescript-lua/issues/174

## Context

The code generator must put every top-level binding of the linked
program somewhere reachable from every other binding. The candidate
stores differ enormously in access cost and in how they interact with
two hard limits of the Lua 5.1 target (the floor pslua compiles for,
see `docs/QUIRKS.md`):

- **200 local variables** per function (`LUAI_MAXVARS`), the chunk's
  main function included.
- **60 upvalues** per function (`LUAI_MAXUPVALUES`), amplified by
  5.1's pass-through accumulation: a nested function reading an outer
  local costs an upvalue slot in *every* intermediate function.

History shaped the current design. Early codegen emitted top-level
bindings as chunk locals — the fastest representation — and real
programs promptly hit both limits (issue #19, "Function at line XXX
has more than 60 upvalues"). The fix was the module-scope table `M`:
every top-level binding becomes a field (`M.Data_Array_map = …`),
fields are unbounded, and `M` itself is the single upvalue any nested
function ever needs. That solved the limits and is the storage this
ADR revisits.

The cost of `M`-only storage is that every inter-binding reference is
a table read: the linked `Data.Array` module has 681 `M.*` references
across 124 bindings. Measured (issue #172's microbenchmarks): reading
`M.field` in a loop is ~2.4× slower than reading a local under PUC
Lua 5.1, and in a LuaJIT trace it is a guarded load where a local is a
register.

Any revisit must handle the limits **by construction** — a design that
merely assumes programs stay small reintroduces #19 as a correctness
cliff.

## Decision

Budget-aware emission with `M` as the overflow valve. Every budget
overflow degrades the specific reference or binding back to the plain
`M` form, so the worst case is exactly the `M`-only output and the
limits stop being correctness cliffs.

### Stage 1: per-function caching of `M` fields (implemented)

Storage is untouched: `M` remains the single source of truth and the
single upvalue, so neither limit can be approached. A Lua-level pass
(`Language.PureScript.Backend.Lua.Localize`, run from
`Language.PureScript.Backend.Lua.Optimizer.optimizeChunk`) caches
`M.x` fields read repeatedly within one function activation into
locals at function entry:

```lua
M.Data_Array_span = function(p, arr)
  local Data_Array_index = M.Data_Array_index
  while true do
    local v = Data_Array_index(arr)(i)
    …
```

This is the classic "localize" optimization from LuaJIT performance
guides. The details that keep it sound and limit-proof:

- **Same-activation rule.** Only reads executing within the caching
  function's own activation are rewritten: reads directly in the body,
  plus reads inside zero-argument immediately-invoked function
  literals (the codegen's expression-position scope wrapper), which
  run synchronously where they stand. Reads inside any other nested
  function literal are left to that function's own caching — hoisting
  them would change *when* they execute relative to module init, which
  the CoreFn laziness analysis may have relied on for recursive
  groups. Within one activation `M` is frozen (its fields are assigned
  only by chunk-level init statements, which cannot interleave with an
  activation), so entry-hoisting a read is value-preserving.

- **Execution-certainty weighting.** Entry-hoisting is a bet: one
  unconditional table read at entry against the reads the body would
  perform. Occurrences are weighted by how often they execute — a read
  in a loop body or `while`/`repeat` condition weighs 2 (one iteration
  breaks even), a read on the unconditional spine weighs 1, a read
  inside a conditional branch (an `if` arm, the right operand of
  `and`/`or`) weighs 0; a field qualifies at total weight ≥ 2. The
  zero weight for branch reads is measured, not theoretical: counting
  them regressed leaf-heavy recursion (naive fib, whose recursive
  reads sit in the non-base branch) by ~25% under PUC Lua, because
  every base-case call paid entry reads it never used. Once a field
  qualifies, all its occurrences in the region are rewritten,
  conditional ones included — the cache exists by then, so those
  rewrites are pure wins.

- **Budgets.** At most 30 caches per function, prioritized by use
  count; a locals ceiling of 180 (against `LUAI_MAXVARS` 200) counting
  parameters and declared locals; an upvalue ceiling of 55 (against
  `LUAI_MAXUPVALUES` 60) for looked-through IIFE protos, computed from
  a conservative over-approximation of their name demand. Overflow
  under-caches; it never breaks.

- **Stability precondition.** The pass verifies, over the whole chunk,
  that inside function bodies the name `M` occurs only as the base of
  field reads — no field writes, no bare/aliasing references, no
  shadowing declarations (shapes only hand-written FFI could produce).
  Otherwise the chunk is left byte-identical.

### Stage 2: two-tier storage with budget accounting (planned)

Top-K bindings by static reference count are emitted as real chunk
locals; the tail stays in `M`; exported bindings are mirrored into the
export surface. Two budgets are computed over the finished Lua AST
before printing:

1. **Locals**: a chunk-local counter with a ceiling of ~180 (200 minus
   fixture locals and headroom). Overflow keeps the binding in `M`.
2. **Upvalues**: the killer of the pre-#19 design. Accounting runs
   bottom-up over the function tree:
   `upvals(f) = |own outer-local references ∪ children's pass-through
   demands|`. When a function proto would exceed ~55, individual
   references are demoted — printed as `M.x` — while the binding stays
   a local for everyone else.

A program that fits the budgets (like `Data.Array` with 124 bindings)
loses the `M` table entirely: pure locals, with the module export
table referencing them directly. `K` for larger programs is chosen
from #172's measurements. Stage 2 lands only with that measurement
backing; until then stage 1's caching already removes the per-loop and
per-call read cost where it matters.

## Rejected alternatives

- **Per-module closure scopes wired by upvalues** — the road that led
  to #19; transitive pass-through accumulation makes the explosion
  structural, not accidental.
- **Globals / `setfenv`** — `GETGLOBAL` in 5.1 is the same hash
  lookup, just on `_G`, and pollutes the global environment.
- **Integer-indexed storage (`B[42]`)** — still a guarded load in
  LuaJIT traces, and the output becomes unreadable.

## Consequences

- Generated functions gain an entry `local … = M.…` statement when
  they read fields repeatedly; goldens churn mechanically but runtime
  behavior is unchanged (eval goldens are the check).
- Hot loops produced by loopification (#181) read loop-invariant
  bindings from locals, which LuaJIT hoists into registers; the win
  compounds with uncurrying (#24) as real loops become traceable.
- The `M` table remains the single upvalue of every generated closure
  until stage 2; nothing about FFI, linking, or DCE changes.
- The budgets live in `Localize.hs` as named constants; stage 2 reuses
  the same ceilings for its chunk-level accounting.
