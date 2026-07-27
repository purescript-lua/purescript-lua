### Added

- Let-bound records read only field-wise unpack to scalars (#240). A
  record literal or record update whose binder never flows anywhere as
  a whole value exists only to be projected or updated again, yet it
  still allocated its table — and every update paid a runtime copy on
  top. Such a binding now explodes into per-field bindings: reads
  become the field values, an update over a known literal is rebuilt
  as a single literal, and a chained update coalesces onto its base
  record with the patch lists merged. The fold reaches across sibling
  `let` bindings, so the defaults pattern dissolves whole. A fold step
  previously compiled to

  ```lua
  local r_S_0 = { lo = i_S_0, hi = i_S_0 + 1 }
  local s_S_0 = PSLUA_object_update(r_S_0, { hi = r_S_0.hi * 2 })
  return acc_S_1 + s_S_0.lo + s_S_0.hi
  ```

  now becomes allocation-free arithmetic:

  ```lua
  return acc_S_1 + i_S_0 + (i_S_0 + 1) * 2
  ```

  4.6× faster under LuaJIT and 5.3× under PUC Lua 5.1 on the
  `Bench.RecordFold` macrobenchmark. Locally-built dictionary records
  collapse the same way — `Golden.LongWriterBind` drops its Writer
  dictionary tower and 57 lines of Lua. A record used as a whole value
  anywhere — returned, passed on, compared — keeps its allocation, the
  soundness boundary `Golden.ScalarReplacement.Test` pins from both
  sides (see `propagateKnownObjectThroughLet` in
  `Language.PureScript.Backend.IR.Optimizer`).
