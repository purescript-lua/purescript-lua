# 1. Top-level binding storage

Date: 2026-07-07

## Status

Accepted. Both stages of issue [#174] are implemented: stage 1
(per-function field caching, `Lua.Localize`) and stage 2 (budget-aware
two-tier storage, `Lua.Promote`).

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

### Stage 2: two-tier storage with budget accounting (implemented)

A Lua-level pass (`Language.PureScript.Backend.Lua.Promote`, run from
`optimizeChunk` *before* stage 1) promotes top-level bindings to real
chunk locals; the tail stays in `M`:

```lua
local Data_Array_index = function(arr) … end
local Data_Array_span = function(p, arr)
  local v = Data_Array_index(arr)(i)
  …
return { span = Data_Array_span, … }
```

- **Selection (the locals budget).** A binding qualifies when its
  field is initialized by exactly one top-level `M.x = e` statement,
  is read at least once, and its name is not used as a variable
  anywhere in the chunk — the promoted local keeps the field's name,
  and on a collision (a shape only hand-written FFI produces) the pass
  declines rather than renames. Qualifying bindings are promoted in
  descending static read count while the chunk's local slots —
  pre-existing declarations plus one per promotion — stay under the
  locals ceiling; the original "top-K" knob from the issue *is* this
  budget bound. Zero-read bindings stay in `M`: a local for a binding
  nobody reads spends a scarce slot on a dead store.
- **Upvalue accounting (the demotion budget).** The killer of the
  pre-#19 design was pass-through accumulation, so the pass computes
  every function proto's upvalue demand bottom-up:
  `demand(f) = ownOuterRefs(f) ∪ {b ∈ demand(child) | b not bound by
  f}`, counting *all* outer-local references (function locals and
  parameters included), resolved lexically — a name referenced before
  its declaration resolves outside it. When a proto's demand exceeds
  the upvalue ceiling, promoted-binding references within its subtree
  are demoted — printed as `M.x` again — cheapest reads first (ties to
  the earlier-declared binding), and the binding is mirrored into the
  table (`M.x = x` right after `local x = e`) so demoted reads still
  observe it. Demoting swaps the binding's upvalue for `M`'s, so the
  first demotion pays off only once `M` is already demanded; the
  fitting loop accounts for that. The binding stays a local for every
  proto that affords it.
- **Recursion.** A binding read before its initializer — the
  self-reference of a recursive function, or an earlier member of a
  mutually recursive group — is pre-declared (`local x` before the
  first referencing statement) and initialized by plain assignment;
  only the forward-referenced group members are pre-declared.
- **Preconditions.** Stage 1's chunk-wide stability precondition,
  plus: the module table is declared exactly once, as `local M = {}`,
  before any other occurrence of the name. Otherwise the chunk is left
  byte-identical.
- **Ordering.** Promotion runs before stage-1 caching: whatever stays
  in `M` after promotion — the unpromoted tail plus demoted
  references — is exactly what per-function caching still speeds up.

A program that fits the budgets loses the `M` table entirely: pure
locals, with the module export table referencing them directly. In the
golden corpus 35 of 50 modules drop `M`; the rest keep it only to hold
bindings that are written but never read (dead stores the IR-level DCE
did not see).

## Rejected alternatives

- **Per-module closure scopes wired by upvalues** — the road that led
  to #19; transitive pass-through accumulation makes the explosion
  structural, not accidental.
- **Globals / `setfenv`** — `GETGLOBAL` in 5.1 is the same hash
  lookup, just on `_G`, and pollutes the global environment.
- **Integer-indexed storage (`B[42]`)** — still a guarded load in
  LuaJIT traces, and the output becomes unreadable.

## Consequences

- In-budget programs emit no `M` table at all: inter-binding
  references are upvalue/register accesses, and the export table
  references the locals directly. Where a binding stays in `M`,
  generated functions still gain stage-1 entry caches (`local … =
  M.…`) for repeated reads; goldens churn mechanically but runtime
  behavior is unchanged (eval goldens are the check).
- Hot loops produced by loopification (#181) read loop-invariant
  bindings from locals, which LuaJIT hoists into registers; the win
  compounds with uncurrying (#24) as real loops become traceable.
- Nothing about FFI, linking, or DCE changes. A binding that is
  written but never read keeps `M` alive for the whole chunk;
  eliminating such dead init stores would be a separate, Lua-level
  DCE concern.
- The hard target limits live in
  `Language.PureScript.Backend.Lua.Limits` as a `LuaLimits` record,
  configurable per target (`--max-locals` / `--max-upvalues`, Lua 5.1
  defaults); both passes budget against working ceilings derived from
  them (hard limit minus headroom, 180/55 by default).
