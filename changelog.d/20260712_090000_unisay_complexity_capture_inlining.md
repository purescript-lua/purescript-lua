### Changed

- Inlining decisions now weigh expression cost and reference position, not
  only use counts and a flat size ceiling (#231). A `Complexity` lattice
  (`Trivial < Deref < KnownSize < NonTrivial`) prices duplicating an
  expression, and a `Capture` lattice (`CaptureNone < CaptureBranch <
  CaptureClosure`) locates a binding's references, admitting two tiers
  through the shared inlining guard: a small projection chain over
  write-once tables pastes at any use count, and a small closed lambda
  whose uses all sit outside branches and closures beta-reduces at every
  site. A non-trivial body is never duplicated into a branch or closure.
