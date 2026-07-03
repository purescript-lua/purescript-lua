module Language.PureScript.Backend.IR.Types.Spec where

import Data.Map qualified as Map
import Hedgehog (PropertyT, annotateShow, forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , Qualified (Imported, Local)
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
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
