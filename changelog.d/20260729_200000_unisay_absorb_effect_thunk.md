### Added

- Effect/ST actions of two or more arguments no longer allocate a closure
  per executed statement (#265). Such an action is already saturated at
  its real arity when the uncurrying worker/wrapper split measures it, so
  the split fires there and magic-do only afterwards rewrites the worker's
  body into the nullary thunk an Effect value is — leaving every fully
  applied statement site to allocate that thunk and immediately force it.
  The late uncurry run cannot repair this: it splits manifest lambda
  chains, and the thunk sits inside a worker that is already n-ary. The
  new `absorbEffectThunk` pass instead widens the worker in place, moving
  the thunk's parameter onto its parameter list, so the site is one n-ary
  call:

  ```lua
  local Golden_EffectWorkerThunk_Test_report_S_w = function(tag, n)
    return function()
      local _ = Effect_Console_log(tag)()
      local _ = Effect_Console_log(Data_Show_showIntImpl(n))()
      return Effect_Console_log("-")()
    end
  end
  local _ = Golden_EffectWorkerThunk_Test_report_S_w("a", 1)()
  ```

  becomes

  ```lua
  local Golden_EffectWorkerThunk_Test_report_S_w = function(tag, n)
    local _ = Effect_Console_log(tag)()
    local _ = Effect_Console_log(Data_Show_showIntImpl(n))()
    return Effect_Console_log("-")()
  end
  local _ = Golden_EffectWorkerThunk_Test_report_S_w("a", 1)
  ```

  The action's curried wrapper grows one parameter so a partial
  application still evaluates to a closure. Taking the run marker into
  the call also makes a recursive driver's self-call a genuine tail call,
  which the native-loop lowering then turns into a Lua `while` — the
  driver of `Bench.EffectStep` went from

  ```lua
  local Bench_EffectStep_go_S_w
  Bench_EffectStep_go_S_w = function(i, ref)
    return function()
      local _ = Bench_EffectStep_step_S_w(ref)
      if i >= 1 and i ~= 1 then
        return Bench_EffectStep_go_S_w(i - 1, ref)()
      else
        return Control_Monad_ST_Internal_read(ref)()
      end
    end
  end
  ```

  to

  ```lua
  local Bench_EffectStep_go_S_w = function(i, ref)
    while true do
      local _ = Bench_EffectStep_step_S_w(ref)
      if i >= 1 and i ~= 1 then
        i, ref = i - 1, ref
      else
        return Control_Monad_ST_Internal_read(ref)()
      end
    end
  end
  ```

  1.22× faster under PUC Lua 5.1 and 1.28× under LuaJIT on the new
  `Bench.EffectStep2` macrobenchmark, and 1.10×/1.14× on the pre-existing
  `Bench.EffectStep`, whose two-argument driver is the same case; that
  spec's trace report loses one `NYI: bytecode FNEW` abort and its driver
  ends compiled as an `ILOOP` instead of interpreted as an `IFUNCF`.

  A worker whose call is bound as an action value and run later keeps the
  call-then-force shape, as does any other reference the widened arity
  would leave under-applied: the Lua backend drops a trailing unused
  parameter run, so an under-applied worker call would run the effect at
  construction time. `Golden.EffectWorkerThunk` pins both sides, including
  a `let`-bound local worker.
