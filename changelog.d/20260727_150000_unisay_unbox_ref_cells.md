### Added

- Non-escaping `Ref`/`STRef` cells unbox to plain mutable Lua locals
  (#239). A cell compiles to a one-field heap table — `new v` allocates
  `{value = v}`, every `read`/`write`/`modify` pays a field access — yet
  a Lua local captured by inner closures is itself a shared mutable slot
  (an upvalue), so when the cell never flows anywhere as a whole value
  the table buys nothing. A `Let`-bound run of `new` whose every use is
  a recognised operation now lowers to `local r = v`, reads to `r`, and
  writes/modifies to assignments, with a literal `modify` function
  beta-reduced at emission so its `{state, value}` record is never
  allocated. An ST loop accumulator previously compiled to

  ```lua
  local acc = Control_Monad_ST_Internal_new(0)()
  for i = 0, n + 1 - 1 do
    Control_Monad_ST_Internal_modifyImpl(function(s_S_0)
      local sPrime_S_0 = s_S_0 + i
      return { state = sPrime_S_0, value = sPrime_S_0 }
    end)(acc)()
  end
  return Control_Monad_ST_Internal_read(acc)()
  ```

  now becomes allocation-free straight-line code:

  ```lua
  local acc = 0
  for i = 0, n + 1 - 1 do
    local s_S_0 = acc
    local sPrime_S_0 = s_S_0 + i
    acc = sPrime_S_0
  end
  return acc
  ```

  Recognition is by qualified name over the cell primitives of
  `Effect.Ref` and `Control.Monad.ST.Internal` plus the ST functor's
  foreign `map_` (the shape `void (modify f r)` inlines to), and only
  run positions lower. A cell used as a first-class value anywhere —
  stored, returned, passed to an unknown function — keeps its boxed
  form, the soundness guard pinned by `Golden.RefUnbox.Test` (see
  `Language.PureScript.Backend.Lua.RefUnbox`).
