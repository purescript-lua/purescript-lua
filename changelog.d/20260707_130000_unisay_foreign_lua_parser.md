### Changed

- Foreign `.lua` files are now read by the compiler's own Lua 5.1 parser
  (megaparsec, `Language.PureScript.Backend.Lua.Parser`) instead of the lexical
  splitter that extracted export values as opaque text blobs by counting
  balanced parentheses. Export values and header statements land in the real
  Lua AST, so Lua-level optimizations no longer stop at a foreign boundary, and
  a syntax error anywhere in an FFI file is a compile-time error rather than a
  luacheck/runtime one. The FFI format contract is relaxed accordingly: export
  values no longer need to be wrapped in parentheses, and comments — which are
  preserved into the generated output via AST annotation slots — may appear
  anywhere, including between export fields (#173).

- The FFI parser matches the reference implementation's rejections: an
  argument-list `(` on a different line than its callee is "ambiguous syntax
  (function call x new statement)" exactly as under `luac` (terminate the
  previous statement with `;` or keep the `(` on the callee's line), and `...`
  outside a vararg function is an error. Syntactic nesting is capped at 500
  levels — far beyond real FFI, the cap only turns adversarially nested input
  into a clean parse error instead of a compiler stack overflow (#173).

- The Lua AST covers the full Lua 5.1 statement/expression grammar (loops,
  `local function`, multiple assignment, method calls, varargs, array-part
  table rows, multi-value `return`). The printer renders nested
  `if`/`else`-of-`if` chains as `elseif`, which also compacts generated
  pattern-matching code; runtime fixtures (`PSLUA_runtime_lazy`,
  `PSLUA_object_update`) are parsed into the AST instead of being emitted as
  verbatim text. Generated-code semantics are unchanged (eval goldens are
  untouched).

### Fixed

- Two printer correctness gaps surfaced by the new `parse . print ≡ id`
  round-trip property (checked over generated chunks, and — parseability-wise
  — over every golden module): a negative numeric literal now carries unary
  precedence, so `(-2) ^ 2` no longer prints as `-2 ^ 2` (which Lua reads as
  `-(2 ^ 2)`), and a statement whose printed form starts with `(` is now
  separated from the preceding statement with `;`, avoiding Lua 5.1's
  "ambiguous syntax" fusion with a preceding expression.
