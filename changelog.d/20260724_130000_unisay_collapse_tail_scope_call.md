### Added

- A tail-position IIFE collapses into the enclosing function body (#230). An
  effectful uncurried definition whose body is a statement sequence — the
  `logTwice = mkEffectFn2 \a b -> do log a; log b` shape from the uncurried
  lifting of #227 — ran its magic-do chunk through a scope call, one closure
  allocation and one extra call per invocation:

  ```lua
  M.Golden_UncurriedLift_Test_logTwice = function(a, b)
    return (function()
      local _ = Effect_Console_log(a)()
      return Effect_Console_log(b)()
    end)()
  end
  ```

  The new Lua-level `collapseTailScopeCall` rule splices the called body in
  place of the `return`, reaching the zero-closure target the pure half of
  #227 already met. Tail position is what makes the splice safe: the parent
  returned all of the call's results immediately, so the inner returns (or
  falling off the end) produce the same values directly, and no parent code
  follows the splice point, so every spliced local resolves as it did inside
  the closure. The rule declines when the spliced statements would rebind
  `...`, and it is budget-aware (#19): the merged body must fit the same
  per-function locals ceiling the storage passes budget against, so two
  adjacent magic-do chunks — `Golden.LongDoBlock.Test`'s 299 locals — keep
  their boundary rather than un-chunking one tail call at a time. Applying
  bottom-up, nested chunk chains collapse as far as the budget allows. Eval
  goldens are unchanged.
