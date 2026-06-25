### Changed

- Documented two more compiler subsystems as GHC-style `Note`s, cited from
  their dependent sites: `Note [Compiling case expressions to decision trees]`
  (the Jacobs-based algorithm, with the scrutinee-binding, column-selection
  heuristic, and match-history pruning sub-rules) and `Note [Foreign bindings
  structure emitted by the Linker]` (the `ForeignImport` plus per-name
  `ObjectProp` shapes that the IR dead-code pass matches by structure). Comments
  only; no change to generated code. Continues #44.
