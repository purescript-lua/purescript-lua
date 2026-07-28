### Changed

- The `.ir` golden files no longer churn on compiler-minted name indices
  (#338). Every IR pass draws fresh binder names from one pipeline-global
  counter, so the index a name carries records how much supply the passes
  before it happened to consume: an optimizer change that mints one extra
  name anywhere renumbers every name after it, and the structural goldens
  then diff on lines whose only change is the counter. The golden harness now
  renumbers each top-level site's minted binders in first-occurrence order
  before rendering, so `m$590` prints as `m$0` and a site's names depend only
  on that site's own structure. Restarting the whole pipeline's supply at
  1000 leaves every golden — `.ir`, `.lua` and `eval/golden.txt` alike —
  byte-identical. The digit-run classifier this shares with the Lua emission
  renumberer moved to `Language.PureScript.Backend.Renumber`, carrying
  Note [Supply-drawn digit runs]; structural suffixes (`f$w`, `f$p1`,
  `pong$sc1Tuple`, uniquification's `x0`) are left alone as before.
  Generated Lua is unchanged.
