module Language.PureScript.Backend.IR.Linker.Spec where

import Data.Set qualified as Set
import Hedgehog ((===))
import Language.PureScript.Backend.IR.Linker (qualifyTopRefs)
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  )
import Language.PureScript.Backend.IR.Types
  ( Grouping (..)
  , lets
  , literalInt
  , noAnn
  , refImported
  , refLocal
  )
import Test.Hspec (Spec, describe)
import Test.Hspec.Hedgehog.Extended (test)

spec ∷ Spec
spec = describe "IR Linker" do
  -- See Note [Sequential scoping of Let bindings]
  describe "qualifyTopRefs" do
    let modname = ModuleName "Main"
        x = Name "x"
        y = Name "y"
        topX = Set.fromList [x]
        qualify = qualifyTopRefs modname topX

    test "ref bound by an earlier sibling is not qualified" do
      let e =
            lets
              ( Standalone (noAnn, x, literalInt 1)
                  :| [Standalone (noAnn, y, refLocal x)]
              )
              (literalInt 0)
      qualify e === e

    test "ref to a top-level name in own RHS is qualified" do
      let original =
            lets (Standalone (noAnn, x, refLocal x) :| []) (literalInt 0)
          expected =
            lets
              (Standalone (noAnn, x, refImported modname x) :| [])
              (literalInt 0)
      qualify original === expected

    test "ref in the body not shadowed by the let is qualified" do
      let original =
            lets (Standalone (noAnn, y, literalInt 1) :| []) (refLocal x)
          expected =
            lets
              (Standalone (noAnn, y, literalInt 1) :| [])
              (refImported modname x)
      qualify original === expected

    test "ref in the body bound by the let is not qualified" do
      let e = lets (Standalone (noAnn, x, literalInt 1) :| []) (refLocal x)
      qualify e === e
