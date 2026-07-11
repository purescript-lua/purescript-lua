### Changed

- The `mk` half of the `*.Uncurried` FFI wrappers now lifts to n-ary
  definitions (#227), completing the pair started by the `run` half (#198).
  The foreign lifter (#178) learned the two missing shapes: a multi-parameter
  function literal becomes a single n-ary `AbsN` (varargs and duplicate
  parameter names decline), and a nullary call becomes an application to the
  `EffectRunArg` marker — the shape magic-do emits, erased back to `()` at
  code generation. `mkFn2`…`mkFn10`, `mkSTFn1`…`mkSTFn10`, and
  `mkEffectFn1`…`mkEffectFn10` join the allowlist as inline-always IR, so a
  definition like `add3 = mkFn3 \a b c -> a + b + c` beta-reduces to the
  n-ary literal itself — `function(a, b, c) return a + b + c end`, zero
  closures per call, where the opaque wrapper re-curried every call through
  two. With both halves lifted, a saturated `runFn3 add3 1 2 3` site calls
  that definition directly as `add3(1, 2, 3)`, and the `mk` accessors drop
  out of the emitted FFI tables just like the `run` ones.
