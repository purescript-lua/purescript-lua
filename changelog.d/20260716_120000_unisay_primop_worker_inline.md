### Fixed

- Arithmetic workers no longer survive un-inlined in hot loop bodies (#281):
  a saturated n-ary worker call whose body is a bare primop over trivial
  operands (the residue of a floated dictionary application such as
  `add = Data.Semiring.add semiringInt`, resolved through the lifted
  foreign) is unfolded at every call site by the call-site inliner, which
  previously only saw unary application spines. Hot loops now pay the
  inline operator instead of a Lua function call per arithmetic operation:
  the `tuple_fold` macro benchmark drops from 0.169s to 0.062s under
  PUC Lua 5.1 (the ideal hand-written loop runs 0.056s).
