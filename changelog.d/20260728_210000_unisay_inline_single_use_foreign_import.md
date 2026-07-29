### Changed

- A foreign module's export table is no longer kept hoisted when exactly one
  once-evaluated site reads it (#251). The compiler binds each FFI module's
  exports to one `ForeignImport` table and reads individual names off it, and
  it used to refuse to fold that table into its reader however few readers
  there were, because an export value can be a Lua table constructor with
  identity (`unit = {}`) that a copy under a lambda would re-allocate per call.
  A new late pass admits the cases where re-evaluation provably cannot happen:
  one reference, a header-free FFI source (a bare `return { … }`, so nothing
  side-effecting moves), and a path from the enclosing top-level right-hand
  side to that reference crossing only positions evaluated exactly once — never
  a lambda body, an `if` branch, or the right operand of `and`/`or`. The
  emitted Lua then loses a table allocation and a hash read per folded import:
  `local M_foreign = { token = {} }` plus `return { token = M_foreign.token }`
  becomes `return { token = {} }`, and a shared accessor collapses in place
  from `local M_log = M_foreign.log` to
  `local M_log = function(s) return function() print(s) end end`.

- The pass runs directly after the accessor-sharing pass (#248), which is the
  last one to change how many references an import has — dissolving an accessor
  multiplies them over the use sites, re-binding a shared read collapses them
  back to one. That placement is what lets it catch both shapes the fold has:
  the read dissolved into an export expression, and the accessor binding kept
  as a shared name whose right-hand side is the import's only reference.
