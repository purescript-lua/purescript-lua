### Changed

- The optimizer's fixpoint oracle no longer compares whole `UberModule`s for
  structural equality (#144). Every pass now returns a change flag (precise for
  the fixpoint members — optimize and DCE — whose rewrite rules report honestly
  since the bottom-up driver change); a fixpoint stops on the first round that
  reports no change, bounded by a generous iteration cap. The production runner
  accepts the module reached at the cap (an early stop only costs optimization,
  never correctness), while the checked runner — used by the test suite and
  `--lint-ir` — fails loudly in both dishonesty directions: a pass that changes
  the module while reporting no change (`PassUnreportedChange`), and a fixpoint
  that fails to converge within the cap (`FixpointDivergence`).
