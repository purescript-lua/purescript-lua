### Added

- Exhaustive matches over closed sum types drop their unreachable default
  (#224), the N-constructor generalisation of the Boolean collapse of #223. A
  `case` covering every constructor of its type still compiled to the full
  chain of tag tests plus a synthesized `error("No patterns matched")`
  catch-all: proving the default dead over a runtime scrutinee needs the
  type's complete constructor set, which no local rewrite could see. The
  declared constructor table (already collected from CoreFn by
  `collectDataDeclarations`) is now threaded into the optimizer, and the new
  `removeUnreachableMatchDefault` rule uses it: when a chain of tag tests
  over one scrutinee variable ends in the synthesized default and the tested
  constructors cover the type's whole declared set, the default is dropped
  and the then-redundant final tag test folds into an unconditional else —
  `if tagA == reflect(v) then a elseif tagB == reflect(v) then b else error`
  becomes `if tagA == reflect(v) then a else b`. Soundness is exact: the
  table is the declared set, so a non-exhaustive chain (or one with a
  repeated test hiding a gap) keeps its default. This is the standard shape
  of generic-deriving output (`Eq`, `Show`, `Functor`), so most goldens
  shrink; eval goldens are unchanged.
