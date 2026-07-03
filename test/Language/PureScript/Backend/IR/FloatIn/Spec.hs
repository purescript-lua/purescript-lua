module Language.PureScript.Backend.IR.FloatIn.Spec where

import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.FloatIn (floatIn)
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter (lintUniqueBinders, lintWellScoped)
import Language.PureScript.Backend.IR.Names
  ( Name (Name)
  , QName (QName)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Query (collectBoundNames)
import Language.PureScript.Backend.IR.SpecUtils
  ( applyPassToExpression
  , emptyUberModule
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , abstraction
  , application
  , countFreeRefs
  , exception
  , ifThenElse
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , refLocal
  )
import Language.PureScript.Backend.IR.Uniquify (uniquifyNamesInExpr)
import Test.Hspec (Spec, describe, it, shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)

spec ∷ Spec
spec = describe "FloatIn" do
  let a = Name "a"
      b = Name "b"
      k = Name "k"
      m = Name "m"
      z = Name "z"
      cond = refLocal (Name "cond")

  it "sinks into the then-branch" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr = lets (pure bindA) (ifThenElse cond (refLocal a) (literalInt 0))
        expected =
          ifThenElse cond (lets (pure bindA) (refLocal a)) (literalInt 0)
    floatInExpression expr `shouldBe` expected

  it "sinks into the else-branch" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr = lets (pure bindA) (ifThenElse cond (literalInt 0) (refLocal a))
        expected =
          ifThenElse cond (literalInt 0) (lets (pure bindA) (refLocal a))
    floatInExpression expr `shouldBe` expected

  it "doesn't sink: the name is used in the condition" do
    -- The name is used in the condition AND in exactly one branch: were
    -- the condition not checked, the branch confinement alone would let
    -- this binding sink (ill-scoping the condition's reference).
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr =
          lets
            (pure bindA)
            (ifThenElse (refLocal a) (refLocal a) (literalInt 0))
    floatInExpression expr `shouldBe` expr

  it "doesn't sink: the name is used in both branches" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr = lets (pure bindA) (ifThenElse cond (refLocal a) (refLocal a))
    floatInExpression expr `shouldBe` expr

  it "doesn't sink across a lambda (the core of #136)" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr =
          lets
            (pure bindA)
            (abstraction (paramNamed (Name "x")) (refLocal a))
    floatInExpression expr `shouldBe` expr

  it
    "sinks to the branch root but never into a lambda inside the branch \
    \(the #136 bug shape)"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          lam = abstraction (paramNamed (Name "x")) (refLocal a)
          expr = lets (pure bindA) (ifThenElse cond lam (literalInt 0))
          expected =
            ifThenElse cond (lets (pure bindA) lam) (literalInt 0)
      floatInExpression expr `shouldBe` expected

  it "doesn't sink: the name is used in a later sibling's right-hand side" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        bindB = Standalone (noAnn, b, refLocal a)
        expr =
          lets (bindA :| [bindB]) (ifThenElse cond (refLocal a) (literalInt 0))
    floatInExpression expr `shouldBe` expr

  it
    "doesn't sink: a RecursiveGroup member's RHS uses the name (and the \
    \RecursiveGroup itself never sinks)"
    do
      -- The name is used in exactly one branch and not in the condition:
      -- only the recursive group's right-hand side blocks the sink.
      let bindA = Standalone (noAnn, a, literalInt 1)
          r1 = Name "r1"
          r2 = Name "r2"
          recGroup =
            RecursiveGroup
              ((noAnn, r1, refLocal a) :| [(noAnn, r2, refLocal r1)])
          expr =
            lets
              (bindA :| [recGroup])
              ( ifThenElse
                  cond
                  (application (refLocal r1) (refLocal a))
                  (literalInt 0)
              )
      floatInExpression expr `shouldBe` expr

  it
    "bare Let-hopping is not progress (regression: without this, \
    \sinking would oscillate forever)"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindB = Standalone (noAnn, b, literalInt 2)
          expr =
            lets
              (pure bindA)
              (lets (pure bindB) (application (refLocal b) (refLocal a)))
      floatInExpression expr `shouldBe` expr

  it "sinks through nested IfThenElse" do
    let bindA = Standalone (noAnn, a, literalInt 5)
        cond1 = refLocal (Name "cond1")
        cond2 = refLocal (Name "cond2")
        expr =
          lets
            (pure bindA)
            ( ifThenElse
                cond1
                (ifThenElse cond2 (refLocal a) (literalInt 0))
                (literalInt 99)
            )
        expected =
          ifThenElse
            cond1
            (ifThenElse cond2 (lets (pure bindA) (refLocal a)) (literalInt 0))
            (literalInt 99)
    floatInExpression expr `shouldBe` expected

  it
    "transits through an intermediate Let whose own binding doesn't use \
    \the name"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindZ = Standalone (noAnn, z, literalInt 9)
          expr =
            lets
              (pure bindA)
              (lets (pure bindZ) (ifThenElse cond (refLocal a) (literalInt 0)))
          expected =
            lets
              (pure bindZ)
              (ifThenElse cond (lets (pure bindA) (refLocal a)) (literalInt 0))
      floatInExpression expr `shouldBe` expected

  it
    "doesn't transit through an intermediate Let whose own binding uses \
    \the name"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindZ = Standalone (noAnn, z, refLocal a)
          expr =
            lets
              (pure bindA)
              (lets (pure bindZ) (ifThenElse cond (refLocal a) (literalInt 0)))
      floatInExpression expr `shouldBe` expr

  it
    "fully collapses an outer Let with two independent bindings, \
    \preserving declaration order"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindB = Standalone (noAnn, b, literalInt 2)
          expr =
            lets
              (bindA :| [bindB])
              ( ifThenElse
                  cond
                  (application (refLocal a) (refLocal b))
                  (literalInt 0)
              )
          expected =
            ifThenElse
              cond
              ( lets
                  (pure bindA)
                  (lets (pure bindB) (application (refLocal a) (refLocal b)))
              )
              (literalInt 0)
      floatInExpression expr `shouldBe` expected

  it
    "a collapsing Let exposes an inner Let, which also sinks, preserving \
    \declaration order (regression: a collapsed Let's body must not \
    \escape the rewrite)"
    do
      let bindK = Standalone (noAnn, k, literalInt 1)
          bindM = Standalone (noAnn, m, literalInt 2)
          expr =
            lets
              (pure bindK)
              ( lets
                  (pure bindM)
                  ( ifThenElse
                      cond
                      (application (refLocal k) (refLocal m))
                      (literalInt 0)
                  )
              )
          expected =
            ifThenElse
              cond
              ( lets
                  (pure bindK)
                  (lets (pure bindM) (application (refLocal k) (refLocal m)))
              )
              (literalInt 0)
      floatInExpression expr `shouldBe` expected

  it
    "an inner sink unblocks the enclosing Let in the same run (regression: \
    \a top-down driver decides an outer Let before its children are \
    \rewritten, breaking idempotence)"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindZ = Standalone (noAnn, z, refLocal a)
          expr =
            lets
              (pure bindA)
              ( lets
                  (pure bindZ)
                  (ifThenElse cond (refLocal z) (literalInt 0))
              )
          expected =
            ifThenElse
              cond
              (lets (pure bindA) (lets (pure bindZ) (refLocal z)))
              (literalInt 0)
      floatInExpression expr `shouldBe` expected
      floatInExpression expected `shouldBe` expected

  it
    "preserves dependency order between two bindings sunk into the same \
    \branch"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindB = Standalone (noAnn, b, refLocal a)
          expr =
            lets
              (bindA :| [bindB])
              (ifThenElse cond (refLocal b) (literalInt 0))
          expected =
            ifThenElse
              cond
              (lets (pure bindA) (lets (pure bindB) (refLocal b)))
              (literalInt 0)
      floatInExpression expr `shouldBe` expected

  it
    "a sunk binding referencing a remaining earlier sibling stays \
    \well-scoped"
    do
      let bindA = Standalone (noAnn, a, literalInt 1)
          bindB = Standalone (noAnn, b, refLocal a)
          expr =
            lets
              (bindA :| [bindB])
              (ifThenElse (refLocal a) (refLocal b) (literalInt 0))
          expected =
            lets
              (pure bindA)
              ( ifThenElse
                  (refLocal a)
                  (lets (pure bindB) (refLocal b))
                  (literalInt 0)
              )
      floatInExpression expr `shouldBe` expected

  it
    "sinks a binding whose right-hand side is an Exception (mirrors the \
    \DCE policy of not special-casing Exception)"
    do
      let bindA = Standalone (noAnn, a, exception "boom")
          expr = lets (pure bindA) (ifThenElse cond (refLocal a) (literalInt 0))
          expected =
            ifThenElse cond (lets (pure bindA) (refLocal a)) (literalInt 0)
      floatInExpression expr `shouldBe` expected

  it "leaves a dead (unused) binding in place" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr =
          lets (pure bindA) (ifThenElse cond (literalInt 5) (literalInt 0))
    floatInExpression expr `shouldBe` expr

  it "rewrites uberModuleBindings, not only exports" do
    let bindA = Standalone (noAnn, a, literalInt 1)
        expr = lets (pure bindA) (ifThenElse cond (refLocal a) (literalInt 0))
        expected =
          ifThenElse cond (lets (pure bindA) (refLocal a)) (literalInt 0)
        qname = QName (moduleNameFromString "Main") (Name "top")
        uber =
          floatIn
            emptyUberModule {uberModuleBindings = [Standalone (qname, expr)]}
    uberModuleBindings uber `shouldBe` [Standalone (qname, expected)]

  describe "properties (generated expressions)" do
    prop 200 "preserves the GUC invariants" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      let optimized =
            floatIn emptyUberModule {uberModuleExports = [(Name "main", e)]}
      lintWellScoped optimized === []
      lintUniqueBinders optimized === []

    prop 200 "preserves free references" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      countFreeRefs (floatInExpression e) === countFreeRefs e

    prop 200 "is idempotent" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      let once = floatInExpression e
      floatInExpression once === once

    prop 200 "preserves the set of bound names" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      collectBoundNames (floatInExpression e) === collectBoundNames e

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

floatInExpression ∷ HasCallStack ⇒ Exp → Exp
floatInExpression = applyPassToExpression "floatInExpression" floatIn
