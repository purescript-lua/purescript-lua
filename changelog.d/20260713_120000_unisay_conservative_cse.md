### Changed

- Added a conservative IR-level CSE pass: alpha-equivalent pure
  subexpressions repeated within one body — lambda literals, non-empty
  array/object literals of effect-free elements, saturated constructor
  applications, and single reads over never-nil bases — are now hoisted
  into a shared `let` binding instead of being re-allocated or re-read
  at every occurrence. Only forms that are effect-free by construction
  participate, repeats never share across a lambda boundary, and a
  function call is never a candidate, so no effect, exception, or
  divergence can move (#183).
