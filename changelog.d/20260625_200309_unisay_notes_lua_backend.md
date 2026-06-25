### Changed

- Documented four Lua-backend invariants as GHC-style `Note`s, cited from their
  dependent sites: `Note [Lua reserved words as foreign export keys]` (the
  `Key`/`reserved`/`toSafeName` round-trip across `Key`, `Name`, and the
  backend), `Note [Lua operator precedence]` (titles the precedence table that
  the `HasPrecedence` instances transcribe and the printer's parenthesisation
  reads), `Note [Foreign module source format]` (the two load-bearing FFI-file
  constraints: paren-wrapped values and a `return`-free header), and `Note
  [Nullary functions and Prim.undefined]` (why `ParamUnused` and the
  `Prim.undefined` argument elision must stay arity-synced). Comments only; no
  change to generated code. Continues #44.
