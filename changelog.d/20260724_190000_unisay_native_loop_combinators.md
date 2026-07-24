### Added

- The Effect/ST loop combinators lower to native Lua loops (#233):
  `foreachE arr f` compiles to `for i = 1, #arr do … end`, `forE lo hi f`
  to the half-open `for i = lo, hi - 1 do … end`, `whileE cond body` to a
  `while` loop, with the ST twins (`Control.Monad.ST.Internal.foreach` /
  `for` / `while`) lowered identically. A run previously compiled to a
  foreign higher-order combinator handed a closure it called once per
  iteration:

  ```lua
  local _ = Effect_foreachE({ 10, 20, 30 })(function(n)
    return Effect_Ref_modify_(function(v) return v + n end, sum)
  end)()
  ```

  now becomes the loop the foreign implementation ran, with the body
  lambda inlined and its parameter as the loop variable — no foreign
  call and no per-iteration closure:

  ```lua
  do
    local xs = { 10, 20, 30 }
    for i = 1, #xs do
      local n = xs[i]
      Effect_Ref_modify_(function(v) return v + n end, sum)()
    end
  end
  ```

  Recognition is by qualified name on a saturated application run by
  magic-do, so a same-named user combinator in another module — or a
  first-class loop combinator passed around unapplied — keeps the
  ordinary call. Non-atomic arguments pre-bind to block-scoped locals,
  preserving the foreign call's once-per-argument evaluation, and a
  thunk body too large to splice under Lua's active-locals cap keeps the
  per-iteration call it had (see
  `Language.PureScript.Backend.Lua.NativeLoop`).
