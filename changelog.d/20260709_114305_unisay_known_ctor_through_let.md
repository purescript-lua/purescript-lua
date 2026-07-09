### Added

- Case-of-known-constructor through a let-bound scrutinee in the IR optimizer
  (#214). When a `Standalone` Let binding's RHS is a saturated constructor
  application and the binder is read only through constructor-eliminating reads,
  the reads fold: `ReflectCtor v` becomes the tag string, and each field read
  (`ObjectProp v "valueᵢ"`, `DataArgumentByIndex i v`) becomes a fresh
  field-binder bound once to the iᵗʰ argument — GHC's case-binder to
  field-binder split, so a non-trivial argument read at several sites is
  evaluated once, not duplicated. The binding is then dropped, its unread
  arguments discarded with the same licence `reduceKnownConstructor` drops a
  field read's siblings. Trivial and dead field-binders inline or DCE away, and
  the folded reads let the surrounding `Eq` / `if` collapse to its live arm,
  reaching the case-of-known-constructor payoff of #177 through a Let. This
  extends the in-place fold to the multiply-read scrutinee that beta reduction
  Let-binds — the shape a dictionary method's several scrutinee reads produce —
  so it is the enabler that makes dictionary-method inlining (#180) pay off. The
  rule declines when the binder is read as a whole value, which dropping it
  would dangle and keeping it would duplicate the arguments. Standalone impact
  is near zero, since the shape appears once #180 inlines a method, so no golden
  moves.
