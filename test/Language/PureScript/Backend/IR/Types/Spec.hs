module Language.PureScript.Backend.IR.Types.Spec where

import Data.Map qualified as Map
import Hedgehog (PropertyT, annotateShow, forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , Qualified (Imported, Local)
  )
import Language.PureScript.Backend.IR.Supply (freshName, runSupply)
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , abstraction
  , alphaEq
  , application
  , countFreeRef
  , countFreeRefs
  , freshenBinders
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , substituteCopyM
  , substituteMoveM
  )
import Language.PureScript.Backend.IR.Uniquify (uniquifyNamesInExpr)
import Test.Hspec (Spec, SpecWith, describe, it, shouldBe)
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

    test "countFreeRefs: ref bound by an earlier sibling is not free" do
      let e =
            lets
              ( Standalone (noAnn, x, literalInt 1)
                  :| [Standalone (noAnn, y, refLocal x)]
              )
              (literalInt 0)
      countFreeRef (Local x) e === 0

    test "countFreeRefs: ref to an outer name in own RHS is free" do
      let e =
            lets (Standalone (noAnn, x, refLocal x) :| []) (literalInt 0)
      countFreeRef (Local x) e === 1

  describe "alphaEq" do
    let x = Name "x"
        y = Name "y"

    -- alphaEq is strictly weaker than (==): structural equality must
    -- always imply alpha-equivalence.
    prop "is reflexive" do
      e ← forAll Gen.exp
      annotateShow e
      alphaEq e e === True

    prop "is symmetric" do
      -- Independent pairs are almost always inequivalent, so this side
      -- exercises the mismatch branches…
      e1 ← forAll Gen.exp
      e2 ← forAll Gen.exp
      annotateShow (e1, e2)
      alphaEq e1 e2 === alphaEq e2 e1
      -- …while the flipped uniquify direction covers the equivalent
      -- case (the Uniquify.Spec property only checks e ~ uniquify e).
      e ← forAll Gen.scopedExp
      alphaEq (uniquifyNamesInExpr e) e === True

    test "identifies λ-terms differing only in binder names" do
      alphaEq
        (abstraction (paramNamed x) (refLocal x))
        (abstraction (paramNamed y) (refLocal y))
        === True

    test "distinguishes references to different binders" do
      -- λx. λy. y  vs  λa. λb. a
      alphaEq
        (abstraction (paramNamed x) (abstraction (paramNamed y) (refLocal y)))
        (abstraction (paramNamed x) (abstraction (paramNamed y) (refLocal x)))
        === False

    test "distinguishes a bound reference from a free one" do
      -- λx. x  vs  λy. x: the left reference is bound, the right is free.
      alphaEq
        (abstraction (paramNamed x) (refLocal x))
        (abstraction (paramNamed y) (refLocal x))
        === False

    test "distinguishes free references by name" do
      alphaEq (refLocal x) (refLocal y) === False

    -- See Note [Sequential scoping of Let bindings]: a Standalone RHS
    -- does not see its own binder, so both references below are free
    -- occurrences of the same enclosing x.
    test "resolves Standalone RHSs against the outer scope" do
      alphaEq
        (lets (Standalone (noAnn, x, refLocal x) :| []) (literalInt 1))
        (lets (Standalone (noAnn, y, refLocal x) :| []) (literalInt 1))
        === True

    test "identifies self-references of recursive-group members" do
      alphaEq
        ( lets
            (RecursiveGroup ((noAnn, x, refLocal x) :| []) :| [])
            (literalInt 1)
        )
        ( lets
            (RecursiveGroup ((noAnn, y, refLocal y) :| []) :| [])
            (literalInt 1)
        )
        === True

  describe "freshenBinders" do
    let x = Name "x"
        y = Name "y"

    it "renames binders and their references, not free references" do
      -- λx. x y: the binder x is freshened, the free y is untouched.
      runSupply
        ( freshenBinders
            ( abstraction
                (paramNamed x)
                (application (refLocal x) (refLocal y))
            )
        )
        `shouldBe` abstraction
          (paramNamed (Name "x$0"))
          (application (refLocal (Name "x$0")) (refLocal y))

    prop "is an alpha-renaming of GUC-shaped input" do
      e ← forAll Gen.scopedExp
      let guc = uniquifyNamesInExpr e
          freshened = runSupply (freshenBinders guc)
      annotateShow freshened
      alphaEq guc freshened === True

  describe "substituteCopyM / substituteMoveM" do
    let x = Name "x"
        y = Name "y"
        identityY = abstraction (paramNamed y) (refLocal y)
        twice = application (refLocal x) (refLocal x)

    it "copy: freshens every inserted occurrence" do
      runSupply (substituteCopyM (Local x) identityY twice)
        `shouldBe` application
          (abstraction (paramNamed (Name "y$0")) (refLocal (Name "y$0")))
          (abstraction (paramNamed (Name "y$1")) (refLocal (Name "y$1")))

    it "move: keeps the first occurrence verbatim, freshens the rest" do
      runSupply (substituteMoveM (Local x) identityY twice)
        `shouldBe` application
          identityY
          (abstraction (paramNamed (Name "y$0")) (refLocal (Name "y$0")))

    it "replaces occurrences without descending into insertions" do
      -- x := y x — the replacement's own reference to x must survive
      -- (a self-referential top-level inlinee is the practical case).
      let replacement = application (refLocal y) (refLocal x)
      runSupply (substituteMoveM (Local x) replacement (refLocal x))
        `shouldBe` replacement

    it "draws no supply names when nothing matches" do
      -- The optimize fixpoint converges and golden numbering stays
      -- stable only because a zero-match substitution is a supply
      -- no-op: see the haddock of 'substituteCopyM'.
      let target = abstraction (paramNamed y) (refLocal y)
      runSupply
        ((,) <$> substituteCopyM (Local x) identityY target <*> freshName "k")
        `shouldBe` (target, Name "k0")

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
                                (refImported (ModuleName "Data.Maybe") (Name "maybe"))
                                (literalInt 0)
                            )
                            ( abstraction
                                (paramNamed (Name "v"))
                                ( application
                                    ( application
                                        (refImported (ModuleName "Data.Array") (Name "add"))
                                        (refLocal (Name "v"))
                                    )
                                    (literalInt 1)
                                )
                            )
                        )
                        ( application
                            ( application
                                (refImported (ModuleName "Data.Array") (Name "findLastIndex"))
                                ( abstraction
                                    (paramNamed (Name "y"))
                                    ( application
                                        ( application
                                            (refImported (ModuleName "Data.Array") (Name "eq1"))
                                            ( application
                                                ( application
                                                    (refLocal (Name "cmp"))
                                                    (refLocal (Name "x"))
                                                )
                                                (refLocal (Name "y"))
                                            )
                                        )
                                        (refImported (ModuleName "Data.Ordering") (Name "GT"))
                                    )
                                )
                            )
                            (refLocal (Name "ys"))
                        )
                    )
                    :| []
                )
                ( application
                    (refImported (ModuleName "Partial.Unsafe") (Name "unsafePartial"))
                    ( abstraction
                        paramUnused
                        ( application
                            (refImported (ModuleName "Data.Array") (Name "fromJust"))
                            ( application
                                ( application
                                    ( application
                                        (refImported (ModuleName "Data.Array") (Name "insertAt"))
                                        (refLocal (Name "i"))
                                    )
                                    (refLocal (Name "x"))
                                )
                                (refLocal (Name "ys"))
                            )
                        )
                    )
                )
            )
        )
    )
