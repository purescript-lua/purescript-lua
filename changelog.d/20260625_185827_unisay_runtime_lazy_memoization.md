### Fixed

- The `PSLUA_runtime_lazy` runtime fixture now memoizes. Its `state` and `val`
  locals were declared inside the forcing thunk, so they reset on every force:
  a lazy recursive binding re-ran its initializer on every reference, returned a
  fresh value each time (breaking reference identity), and looped instead of
  reporting the "needed before it finished initializing" error on an ill-founded
  cycle. The locals now live in the enclosing closure, so the initializer runs
  at most once. A new `Lua.Run` test forces a counted initializer twice and
  asserts it ran once.
