### Changed

- The IR optimizer no longer needs one whole-module sweep per layer of a
  constant chain, so compile time stops scaling with the depth of the deepest
  such chain (#328). Every fold that eliminates a let-bound constructor leaves
  the payload behind in a spent field-binder — a `Let` nothing reads any more:

  ```
  let v = Just 2 in                     ->   let $field = 2 in
    if justTag == reflectCtor v              Just 3
      then Just (arg0 v + 1) else Nothing
  ```

  Only the separate dead-code-elimination pass dropped that residue, one pass
  later in the round. Until it did, the enclosing layer's right-hand side was a
  `Let` rather than the `Just 3` it wraps, so the fold there declined and the
  chain advanced by exactly one layer per round. Dropping an unread binding is
  now also a rewrite (`removeUnusedLetBindings`), on the licence dead-code
  elimination already used — an effect run stays, anything else is evaluated
  for a value nothing wants — so the whole cascade completes inside one sweep.

  A ~300-deep chain now converges in as many rounds as a three-deep one:
  `Golden.LongBindFlipped`'s `specialize+dce` fixpoint goes from 301 rounds to
  3, and the deepest fixpoint over the whole golden corpus takes 4. Compiling
  `Golden.LongApplyChain` drops from 42.6s to 1.2s, `Golden.LongBindFlipped`
  from 8.2s to 1.2s, and the golden suite as a whole from 81.9s to 30.2s.

- The optimizer fixpoint iteration backstop (`maxFixpointIterations`) is 100
  rounds. Legitimate convergence no longer scales with chain depth, so the
  bound can sit close to real work (4 rounds at the corpus maximum) and a pass
  that over-reports changes or genuinely loops is caught after 100 sweeps
  rather than 1000.

- Collapsing the chains within the sweep unblocks a fold the growth veto used
  to stall: `Golden.LongWriterBind` compiled a 200-deep `Writer` chain into a
  nest of closures over `tell`/`discard` plus the `Data.Identity` dictionary
  tables, and now compiles to straight-line code — the result's first component
  is the literal `42`, the log a flat `concatArray` spine, and the dictionaries
  are gone (847 lines of Lua down to 234). The module's execution output is
  unchanged.
