### Changed

- A data-constructor value compiles to an array-part Lua table: the
  `Module∷Type.Ctor` tag string in slot 1 (sum types only) and the fields
  in the slots after it, replacing the hash-part
  `{["$ctor"] = …, value0 = …}` layout — about 1.4x faster on the
  allocate-and-match microbenchmark under PUC Lua 5.1, and smaller, since
  constructor tables no longer allocate hash slots. The layout is
  FFI-visible: foreign code that reads `value0` / `["$ctor"]` off a
  PureScript data value or hand-builds such values must switch to
  positional access. An audit of every `.lua` file in the published
  package set found no such code — the FFI surface is
  constructor-abstract (#185).
