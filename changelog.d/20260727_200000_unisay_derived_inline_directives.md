### Added

- Inline directives are now derived for specialization bindings (#241). A
  top-level binding whose settled shape applies a directive-carrying
  combinator to some of its arguments — the shape purs's common-subexpression
  pass floats for repeated dictionary applications (`bind = Control.Bind.bind
  bindStateT`), and the shape of a hand-written partial application — needs
  no pragma of its own: with the combinator under `@inline f arity=N` and the
  binding applying `k` arguments, the binding inherits `arity=(N-k)` when
  under-applied and always-inline when saturated (`k >= N`), transitively
  through chains of such bindings. A specialized combinator then inlines at
  its qualifying call sites with no hand-written annotation, while explicit
  directives on the specialization keep full precedence.
