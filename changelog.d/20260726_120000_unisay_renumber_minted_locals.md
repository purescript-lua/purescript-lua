### Changed

- Compiler-minted local names are renumbered at emission time, immediately
  before printing: every supply-drawn index (`x_S_223`, `_S_cse1413`, and the
  index a derived dispatcher name embeds, `b_S_5_S_loop`) is rewritten in
  first-occurrence order per base name, counted from 0. Emitted names are now
  a function of the artifact's own structure, so upstream changes that merely
  shift name-supply consumption no longer rename binders in unrelated modules.
  One-time whole-corpus renaming of generated Lua; runtime semantics are
  unchanged (#306).
