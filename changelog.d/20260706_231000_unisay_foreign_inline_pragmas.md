### Fixed

- `@inline <name> never` now works for foreign export names. The pragma
  annotation was parsed and carried up to the linker, which discarded it and
  hard-coded `Always` on the accessor it binds each foreign name to; the
  accessor also escaped the optimizer's `never` veto because it is collected
  before foreigns merge into the bindings. The linker now applies the name's
  pragma to the accessor (defaulting to `Always`), and the veto set includes
  foreign accessors, so a fork can pin an FFI value to a single shared
  binding (#175).
