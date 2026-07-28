### Changed

- The budgeted call-site inliner now admits saturated n-ary worker calls —
  the direct `f$w(a, b)` calls the uncurrying split mints — under the same
  size budget as curried call spines, instead of only bare-primop worker
  bodies. Small workers (dictionary-method residues, constructors, tiny
  helpers) dissolve into their call sites, where the pasted bodies meet the
  constructor and primop folds and frequently reduce to constants. The
  growth veto now falls back one rung at a time: a sweep whose n-ary worker
  pastes overrun the expression's growth allowance is redone with only the
  curried paste tiers armed before every heuristic tier is disarmed, so the
  new pastes can never crowd out a previously collapsing dictionary-method
  cascade (#245).
