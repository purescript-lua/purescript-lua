module Language.PureScript.Backend.IR.Types.Spec where

import Data.Map qualified as Map
import Hedgehog (PropertyT, annotateShow, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , Qualified (Imported, Local)
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , Index
  , abstraction
  , alphaEq
  , application
  , countFreeRef
  , countFreeRefs
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , shift
  , substitute
  , unshift
  )
import Test.Hspec (Spec, SpecWith, describe, it)
import Test.Hspec.Hedgehog (hedgehog, modifyMaxShrinks, modifyMaxSuccess)
import Test.Hspec.Hedgehog.Extended (test)

{- | Like 'test', but runs the property over many generated inputs. The bare
'test' helper pins maxSuccess to 1, which is fine for example-based checks
but too weak for the algebraic laws below.
-}
prop ∷ String → PropertyT IO () → SpecWith ()
prop title =
  modifyMaxShrinks (const 20)
    . modifyMaxSuccess (const 100)
    . it title
    . hedgehog

spec ∷ Spec
spec = describe "Types" do
  test "countFreeRefs" do
    countFreeRefs expr
      === Map.fromList
        [ (Imported (ModuleName "Data.Array") (Name "add"), 1)
        , (Imported (ModuleName "Data.Array") (Name "eq1"), 1)
        , (Imported (ModuleName "Data.Array") (Name "findLastIndex"), 1)
        , (Imported (ModuleName "Data.Array") (Name "fromJust"), 1)
        , (Imported (ModuleName "Data.Array") (Name "insertAt"), 1)
        , (Imported (ModuleName "Data.Maybe") (Name "maybe"), 1)
        , (Imported (ModuleName "Data.Ordering") (Name "GT"), 1)
        , (Imported (ModuleName "Partial.Unsafe") (Name "unsafePartial"), 1)
        ]

  -- See Note [Sequential scoping of Let bindings]
  describe "Let sequential (let*) scoping" do
    let x = Name "x"
        y = Name "y"

    test "shift: ref bound by an earlier sibling is not shifted" do
      let e =
            lets
              ( Standalone (noAnn, x, literalInt 1)
                  :| [Standalone (noAnn, y, refLocal x 0)]
              )
              (literalInt 0)
      shift 1 x 0 e === e

    test "shift: ref to an outer name in own RHS is shifted" do
      let original =
            lets (Standalone (noAnn, x, refLocal x 0) :| []) (literalInt 0)
          shifted =
            lets (Standalone (noAnn, x, refLocal x 1) :| []) (literalInt 0)
      shift 1 x 0 original === shifted

    test "shift: ref in the body bound by the let is not shifted" do
      let e =
            lets (Standalone (noAnn, x, literalInt 1) :| []) (refLocal x 0)
      shift 1 x 0 e === e

    test "countFreeRefs: ref bound by an earlier sibling is not free" do
      let e =
            lets
              ( Standalone (noAnn, x, literalInt 1)
                  :| [Standalone (noAnn, y, refLocal x 0)]
              )
              (literalInt 0)
      countFreeRef (Local x) e === 0

    test "countFreeRefs: ref to an outer name in own RHS is free" do
      let e =
            lets (Standalone (noAnn, x, refLocal x 0) :| []) (literalInt 0)
      countFreeRef (Local x) e === 1

    test "substitute: ref bound by an earlier sibling is not substituted" do
      let e =
            lets
              ( Standalone (noAnn, x, literalInt 1)
                  :| [Standalone (noAnn, y, refLocal x 0)]
              )
              (literalInt 0)
      substitute (Local x) 0 (literalInt 42) e === e

    test "substitute: ref to an outer name in own RHS is substituted" do
      let original =
            lets (Standalone (noAnn, x, refLocal x 0) :| []) (literalInt 0)
          expected =
            lets (Standalone (noAnn, x, literalInt 42) :| []) (literalInt 0)
      substitute (Local x) 0 (literalInt 42) original === expected

  describe "shift / unshift (De Bruijn re-indexing)" do
    let x = Name "x"
        y = Name "y"

    -- 'unshift' is the inverse of 'shift 1': raising every free reference to a
    -- name and then lowering it again must return the original expression.
    prop "unshift undoes shift 1 (round-trip)" do
      e ← forAll Gen.exp
      n ← forAll Gen.name
      minIndex ← forAll (Gen.integral (Range.linear (0 ∷ Index) 3))
      annotateShow e
      unshift n minIndex (shift 1 n minIndex e) === e

    test "unshift: a reference bound above minIndex is lowered" do
      unshift x 0 (refLocal x 2) === refLocal x 1

    test "unshift: the reference at minIndex (removed binder) is left alone" do
      unshift x 1 (refLocal x 1) === refLocal x 1

    test "unshift: a reference to a different name is untouched" do
      unshift x 0 (refLocal y 3) === refLocal y 3

    test "unshift: only references free under a shadowing binder are lowered" do
      -- under \x the inner reference x@0 is bound by it (left alone), while the
      -- outer reference x@2 is free and must drop to x@1.
      unshift x 0 (abstraction (paramNamed x) (refLocal x 0))
        === abstraction (paramNamed x) (refLocal x 0)
      unshift x 0 (abstraction (paramNamed x) (refLocal x 2))
        === abstraction (paramNamed x) (refLocal x 1)

  describe "substitute (capture-avoiding)" do
    -- Replacing a variable by a reference to itself (at the same index) is the
    -- identity: this exercises the capture-avoiding shifting that 'substitute'
    -- performs as it descends under same-named binders.
    prop "substituting a variable for itself is the identity" do
      e ← forAll Gen.exp
      n ← forAll Gen.name
      index ← forAll (Gen.integral (Range.linear (0 ∷ Index) 3))
      annotateShow e
      substitute (Local n) index (refLocal n index) e === e

    -- The classic textbook cases the property above can only sample at random.
    let x = Name "x"
        y = Name "y"
        z = Name "z"

    -- (λy. x)[x ≔ y] must not capture the free y: in De Bruijn terms the
    -- replacement's y is shifted to index 1 so it keeps referring to the outer
    -- y rather than the λ that now encloses it.
    test "a free variable is not captured by a binder of its name" do
      substitute
        (Local x)
        0
        (refLocal y 0)
        (abstraction (paramNamed y) (refLocal x 0))
        === abstraction (paramNamed y) (refLocal y 1)

    -- (λz. x)[x ≔ y]: z shadows neither x nor y, so the result is just (λz. y).
    test "substitution passes through an unrelated binder unchanged" do
      substitute
        (Local x)
        0
        (refLocal y 0)
        (abstraction (paramNamed z) (refLocal x 0))
        === abstraction (paramNamed z) (refLocal y 0)

    -- (λx. x)[x ≔ 42]: the inner x is bound by its own λx, not the variable
    -- being substituted, so the redex is left untouched.
    test "a shadowing binder of the same name stops the substitution" do
      substitute
        (Local x)
        0
        (literalInt 42)
        (abstraction (paramNamed x) (refLocal x 0))
        === abstraction (paramNamed x) (refLocal x 0)

    -- (λx. x⟨outer⟩)[x ≔ y]: here the body's reference points past the binder
    -- (index 1), so it is the one being substituted; the replacement y is not
    -- captured by λx, so it stays at index 0.
    test "a reference reaching past a shadowing binder is substituted" do
      substitute
        (Local x)
        0
        (refLocal y 0)
        (abstraction (paramNamed x) (refLocal x 1))
        === abstraction (paramNamed x) (refLocal y 0)

  describe "alphaEq" do
    let x = Name "x"
        y = Name "y"

    -- alphaEq is strictly weaker than (==): structural equality must
    -- always imply alpha-equivalence.
    prop "is reflexive" do
      e ← forAll Gen.exp
      annotateShow e
      alphaEq e e === True

    test "identifies λ-terms differing only in binder names" do
      alphaEq
        (abstraction (paramNamed x) (refLocal x 0))
        (abstraction (paramNamed y) (refLocal y 0))
        === True

    test "distinguishes references to different binders" do
      -- λx. λy. y  vs  λa. λb. a
      alphaEq
        (abstraction (paramNamed x) (abstraction (paramNamed y) (refLocal y 0)))
        (abstraction (paramNamed x) (abstraction (paramNamed y) (refLocal x 0)))
        === False

    test "distinguishes a bound reference from a free one" do
      -- λx. x  vs  λy. x: the left reference is bound, the right is free.
      alphaEq
        (abstraction (paramNamed x) (refLocal x 0))
        (abstraction (paramNamed y) (refLocal x 0))
        === False

    test "identifies free references past differently-named binders" do
      -- λx. x@1  and  λy. x@0  both refer to the same enclosing x.
      alphaEq
        (abstraction (paramNamed x) (refLocal x 1))
        (abstraction (paramNamed y) (refLocal x 0))
        === True

    test "distinguishes free references by name" do
      alphaEq (refLocal x 0) (refLocal y 0) === False

    -- See Note [Sequential scoping of Let bindings]: a Standalone RHS
    -- does not see its own binder, so both references below are free
    -- occurrences of the same enclosing x.
    test "resolves Standalone RHSs against the outer scope" do
      alphaEq
        (lets (Standalone (noAnn, x, refLocal x 0) :| []) (literalInt 1))
        (lets (Standalone (noAnn, y, refLocal x 0) :| []) (literalInt 1))
        === True

    test "identifies self-references of recursive-group members" do
      alphaEq
        ( lets
            (RecursiveGroup ((noAnn, x, refLocal x 0) :| []) :| [])
            (literalInt 1)
        )
        ( lets
            (RecursiveGroup ((noAnn, y, refLocal y 0) :| []) :| [])
            (literalInt 1)
        )
        === True

expr ∷ Exp
expr =
  abstraction
    (paramNamed (Name "cmp"))
    ( abstraction
        (paramNamed (Name "x"))
        ( abstraction
            (paramNamed (Name "ys"))
            ( lets
                ( Standalone
                    ( noAnn
                    , Name "i"
                    , application
                        ( application
                            ( application
                                (refImported (ModuleName "Data.Maybe") (Name "maybe") 0)
                                (literalInt 0)
                            )
                            ( abstraction
                                (paramNamed (Name "v"))
                                ( application
                                    ( application
                                        (refImported (ModuleName "Data.Array") (Name "add") 0)
                                        (refLocal (Name "v") 0)
                                    )
                                    (literalInt 1)
                                )
                            )
                        )
                        ( application
                            ( application
                                (refImported (ModuleName "Data.Array") (Name "findLastIndex") 0)
                                ( abstraction
                                    (paramNamed (Name "y"))
                                    ( application
                                        ( application
                                            (refImported (ModuleName "Data.Array") (Name "eq1") 0)
                                            ( application
                                                ( application
                                                    (refLocal (Name "cmp") 0)
                                                    (refLocal (Name "x") 0)
                                                )
                                                (refLocal (Name "y") 0)
                                            )
                                        )
                                        (refImported (ModuleName "Data.Ordering") (Name "GT") 0)
                                    )
                                )
                            )
                            (refLocal (Name "ys") 0)
                        )
                    )
                    :| []
                )
                ( application
                    (refImported (ModuleName "Partial.Unsafe") (Name "unsafePartial") 0)
                    ( abstraction
                        paramUnused
                        ( application
                            (refImported (ModuleName "Data.Array") (Name "fromJust") 0)
                            ( application
                                ( application
                                    ( application
                                        (refImported (ModuleName "Data.Array") (Name "insertAt") 0)
                                        (refLocal (Name "i") 0)
                                    )
                                    (refLocal (Name "x") 0)
                                )
                                (refLocal (Name "ys") 0)
                            )
                        )
                    )
                )
            )
        )
    )
