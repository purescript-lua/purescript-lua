### Added

- Constructed Product Result worker/wrapper split (#206). A function whose
  every return path builds the same constructor — a State-shaped bind step
  returning one `Tuple` per call, an `uncons`-style helper returning a
  record-like product — is split into a worker returning the constructor's
  fields as Lua multiple values (`return a, s2`) and a wrapper that reboxes
  them under the original name. A call site that immediately deconstructs
  the result is rewritten to bind the components straight off the worker
  call (`local a, s2 = step$r(s)`), so the per-call table never exists;
  callers that consume the product as a first-class value keep going
  through the wrapper, unchanged. Two new IR nodes (`Values`, `LetValues`)
  carry the multi-value convention, guarded by a `WellApplied` lint that
  rejects a multi-value expression outside a return-or-bind position at
  every checked pass boundary. On the new `Bench.StateStep` benchmark the
  per-iteration table allocation (function-body TNEW in the new
  `tnew_census` report) drops to zero.
