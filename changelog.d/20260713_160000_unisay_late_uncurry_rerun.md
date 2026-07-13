### Changed

- The uncurrying worker/wrapper split (#24) now runs a second time at the end
  of the IR pipeline, catching the two saturated-call families the early run
  cannot see: effect functions whose thunk-forcing application only appears
  once magic-do has run — the worker absorbs the thunk parameter, so a fully
  applied effect statement compiles to one n-ary call instead of a curried
  call plus a thunk allocation and force — and the `$kont` continuation
  helpers minted by `flattenDeepBinds`, saturated by construction. The pass is
  rerun-safe (wrappers built by the early run are recognised and reused, never
  split again), effect statements keep their dead-code protection through the
  rewrite (`isEffectRun` recognises the absorbed trailing marker), and a
  closing dce pass drops the wrappers whose sites were all saturated (#200).
