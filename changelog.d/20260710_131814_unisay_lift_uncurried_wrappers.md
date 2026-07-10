### Changed

- The `run` half of the `*.Uncurried` FFI wrappers now lifts to direct n-ary
  calls (#198). Building on the foreign lifter (#178) and the `AppN` node
  (#179), `runFn2`…`runFn10`, `runSTFn1`…`runSTFn10`, and
  `runEffectFn1`…`runEffectFn10` are lifted from their curried runtime
  fallbacks to inline-always IR: `runFn3` becomes `\fn a b c -> AppN fn [a, b,
  c]`, and `runSTFn2` becomes `\fn a b -> Abs _ (AppN fn [a, b])` (the trailing
  effect thunk is a unary lambda with an unused parameter). A saturated call
  site then beta-reduces to a single n-ary Lua call, so `runFn3 impl x y z`
  compiles to `impl(x, y, z)` rather than the two-closure curried onion; a
  partial application keeps the wrapper's curried fallback. The `mk`
  counterparts need an n-ary `AbsN` (#24) and stay opaque.
- An `Effect`/`ST` statement whose action is a lifted uncurried wrapper now
  sheds its final closure at code generation: the effect run of a literal thunk,
  `(\_ -> fn(a, …)) EffectRunArg`, lowers straight to the call `fn(a, …)`
  instead of `(function() return fn(a, …) end)()`. The `EffectRunArg` marker is
  kept through the IR pipeline so dead-code elimination still keeps the
  result-unused effect statement; only the Lua backend drops the redundant
  force. On the ST/Array boundary this turns `runSTFn2(pushImpl)(x)(arr)()` from
  four calls and three closures into one `pushImpl(x, arr)`.
