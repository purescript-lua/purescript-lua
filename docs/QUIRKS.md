# Compiling to Lua with pslua — behaviors & gotchas

A guide for people writing PureScript and compiling it to Lua with `pslua`:
how PureScript values map onto Lua, what you need to know to write FFI, and the
handful of surprises worth knowing up front.

> This page is for **users** of the compiler. Compiler-internal pitfalls live
> in `CLAUDE.md` and in inline source Notes.

## Target: Lua 5.1

`pslua` targets **stock Lua 5.1**. Code it emits — and any FFI you write — must
run there. The things most likely to trip you up, because they exist in later
Lua but not 5.1:

- **Missing:** `table.unpack` / `table.pack` / `table.move`, the `bit32`
  library, the `utf8` library, the `//` floor-division operator.
- **Present (but easy to forget they moved later):** `math.pow`, `math.atan2`.
- Tables are **1-indexed**.
- Relational operators (`<`, `>`, …) **error** on booleans instead of coercing.
- `error(msg)` at level ≥1 prepends `chunk:line:` to your message. Use
  `error(msg, 0)` to raise the raw string unchanged.

If your FFI uses a 5.2+ builtin it will work under a newer interpreter and fail
under 5.1 — test on 5.1.

## How PureScript values look in Lua

| PureScript | Lua |
|---|---|
| `Int`, `Number` | `number` (5.1 numbers are doubles) |
| `String`, `Char` | `string` (a **byte** string — see below) |
| `Boolean` | `boolean` |
| `Array a` | table, **1-indexed** |
| record `{ a, b }` | table keyed by field name (`t.a`, `t.b`) |
| `Unit` | `{}` (empty table) — **never `nil`** |
| function `a -> b -> c` | **curried**: call as `f(a)(b)` |
| `Effect a` | a **nullary thunk** `function() … return a end`; run it by calling `m()` |
| data constructor | table carrying a tag plus its fields |

Notes that bite in practice:

- **`Unit` is `{}`, not `nil`** — because Lua tables can't store `nil` (a `nil`
  field just doesn't exist). The same rule applies to your own FFI: never put
  `nil` into an array or record you build, or those elements silently vanish.
- **Strings/Chars are byte strings.** A non-ASCII code point is *several* bytes.
  Code-point-aware operations go through `Data.String.CodePoints`;
  `Data.String.CodeUnits` slices **byte-wise**. If you write FFI that consumes a
  `Char`, it may receive either a single byte (from `CodeUnits`) or a full
  multibyte sequence (from a literal) — handle both, e.g. guard on `#c` before
  reading `c:byte(2)`.
- **`Effect` is a thunk.** FFI that produces an `Effect a` must return a
  *function* that, when called, performs the action and returns the `a`. FFI
  that produces a plain `a` returns the value directly.

## Writing FFI: the foreign module shape

A foreign `.lua` file is an ordinary Lua 5.1 module: an optional **header** of
shared helpers followed by a single `return` of an **exports table**. The
compiler parses the whole file with its own Lua 5.1 parser, so a syntax error
anywhere in the file is a compile-time error.

- The header is any sequence of Lua statements (typically `local` helpers), in
  scope for the exported values. Lua's own grammar guarantees the exports
  `return` is the last top-level statement.
- The exports are a single returned table of fields. Each field must be keyed
  by an identifier (`key = <lua expression>`) or, for an export named after a
  Lua keyword, by a bracketed string (`["if"] = …`). Values need no special
  wrapping.
- Comments are allowed anywhere, including between table fields, and are
  preserved in the generated output.
- Lua 5.1's "ambiguous syntax" rule applies, as it does under `luac`: a line
  that starts with `(` right after an expression is rejected as an ambiguous
  function call — end the previous statement with `;` or keep the `(` on the
  same line as the callee.
- Top-level `...` is rejected: the file is embedded into a function scope in
  the generated output, so chunk varargs (e.g. the `local name = ...`
  module-name idiom) cannot work there. `...` inside the file's own vararg
  functions is fine.

```lua
-- header: shared helpers
local function helper(x)
  return x + 1
end

return {
  foo = function(a) return helper(a) end,
  -- comments between fields are fine
  bar = function(a) return function(b) return a + b end end,
}
```

## Very long `do` blocks

A straight-line `do` block compiles to a chain of `bind`/`discard` whose
continuations nest lexically, and Lua's parser caps how deeply expressions may
nest (~200 levels). A long enough chain would fail to **load** (before any code
runs) with `chunk has too many syntax levels`.

The compiler now flattens these so they have no practical length limit:

- **`Effect` and `ST`** blocks are lowered to a plain statement sequence
  (magic-do).
- **Any other monad** — `Maybe`, `Either`, `State`, a custom parser/decoder —
  has its continuation chain **lambda-lifted**: long chains of any
  `f action (\x -> …)` shape (`bind`/`>>=`, non-`bind` CPS, `bracket`/`with`
  combinators) are split into segments and each segment's continuation becomes a
  small named helper, so the generated nesting stays flat regardless of chain
  length ([#104](https://github.com/purescript-lua/purescript-lua/issues/104)).
- **Applicative / flipped-bind chains** whose depth lives in a value-argument
  position — `ado`/`apply` (`<*>`), `bindFlipped` (`=<<`), deep left-associated
  `<>`, or any other nested call spine — are **sequentialised**: the deepest
  application path is rebuilt into a flat sequence of `local` statements, sealing
  a `$tmp` every ~40 applications (segmented, so each `local` stays shallow *and*
  the local count stays well under Lua's 200-per-function cap)
  ([#108](https://github.com/purescript-lua/purescript-lua/issues/108)).

A few related shapes are **not** flattened yet and can still hit the limit at
~200+ levels in a single expression:

- A `bind` chain that forwards more than ~15 distinct earlier-bound variables
  through a single cut: the lambda-lifter **bails** (a segment's helpers carry
  those forwarded variables *plus* the segment's own binders as upvalues, which
  would approach Lua 5.1's 60-upvalue cap, see below) and leaves it nested.
- Deep nesting from branch constructs: a giant `case` tree (nested
  `if`/`then`/`else`), whose hoisting must stay branch- and laziness-aware, or a
  very wide array/record literal.

When one of these would overflow, the compiler now **rejects it with a clear
error** (`Expression nests too deeply for Lua 5.1 …`) instead of emitting a Lua
file that no interpreter can load. **If you hit it:** split the expression into
smaller named pieces (extract sub-computations into separate functions and
sequence them), or break a wide literal/decode into chunks.

## Lua's per-function size limits (locals & upvalues)

Separate from the parser-nesting limit above, Lua 5.1 caps the *contents* of a
single function at load time:

- **~200 local variables** per function (`LUAI_MAXVARS`). Exceeding it fails to
  load with `function at line N has more than 200 local variables`.
- **~60 upvalues** per function (`LUAI_MAXUPVALUES`) — variables a closure
  captures from an enclosing scope. Exceeding it fails with
  `function at line N has more than 60 upvalues`. (Lua ≥5.2 raises this to 255;
  5.1 is the floor pslua targets.)

Both have bitten the compiler before: long `Effect` chains used to build deeply
nested closures, each capturing many top-level references as upvalues
([#19](https://github.com/purescript-lua/purescript-lua/issues/19)). The
compiler now keeps its own output within these limits — Effect/ST `do` blocks
are flattened to a flat statement sequence (no capturing closure per step), and
that sequence is chunked so no generated function exceeds the local-variable
limit.

If you write your own FFI, the same caps apply to *your* Lua: a single function
with hundreds of locals, or one that captures more than ~60 distinct outer
variables, will not load under Lua 5.1 — split it into smaller functions.

## Deep recursion & stack safety

Lua has proper tail calls, so a function whose recursive call is in tail
position (`return go(next)`) loops in constant stack. But non-tail recursion —
especially building up a monadic computation by recursing — can overflow the Lua
stack at runtime, just as on other backends.

For stack-safe monadic loops use `Control.Monad.Rec.Class` (`tailRecM`,
`tailRecM2`, `forever`) instead of open recursion. Its `Effect` instance runs as
a real loop, so it stays in constant stack regardless of iteration count.
