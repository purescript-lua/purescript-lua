### Added

- A tail-position application of a function literal splices into the
  enclosing function body (#295). #230 and the trailing-call fold removed
  the scope-call closures but stopped one step short: when the pushed
  application landed on a returned function literal, the beta-redex
  stayed — one closure allocation and one extra call per invocation.
  `Golden.LongApplyChain.Test`'s `applySecond` carried the shape on every
  node of its 40-deep apply chain:

  ```lua
  return (function(v1_S_626)
    if "Data.Maybe∷Maybe.Just" == v_S_625[1] then
      ...
    end
  end)(b_S_134)
  ```

  The generalized rule — `collapseTailLiteralApplication`, formerly
  `collapseTailScopeCall` — binds the parameters as one simultaneous
  `local` and splices the body:

  ```lua
  local v1_S_626 = b_S_134
  if "Data.Maybe∷Maybe.Just" == v_S_625[1] then
    ...
  end
  ```

  The one-statement `local` is the exact translation of Lua's call
  binding (the whole initializer list evaluates before any name binds,
  the last expression expands its multiple values, missing values fill
  with `nil`), and the arguments stay at the same program point in the
  same scope. `foldCallThroughScopeCall` also hands each literal it
  rebuilds to the collapse, so the redexes it creates at depths the
  bottom-up driver has already passed reduce even in expression position
  — a table row or an operand, as in `Golden.Issue37.Test` and
  `Golden.StringCodePoints.Test`. In `Golden.LongWriterBind.Test` the
  chain composes with the projection folds far enough to drop the last
  read of a dictionary combinator altogether. Eval goldens are unchanged.
