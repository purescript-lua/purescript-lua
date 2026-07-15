module Language.PureScript.Backend.IR.Uniquify.Spec where

import Hedgehog (PropertyT, annotateShow, forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( lintUniqueBinders
  , lintWellScoped
  )
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , abstraction
  , alphaEq
  , application
  , letValues
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , refLocal
  )
import Language.PureScript.Backend.IR.Uniquify
  ( uniquifyNames
  , uniquifyNamesInExpr
  )
import Language.PureScript.Names (runtimeLazyName)
import Test.Hspec (Spec, SpecWith, describe, it, shouldBe)
import Test.Hspec.Hedgehog (hedgehog, modifyMaxShrinks, modifyMaxSuccess)

{- | Like 'Test.Hspec.Hedgehog.Extended.test', but runs the property
over many generated inputs.
-}
prop ∷ String → PropertyT IO () → SpecWith ()
prop title =
  modifyMaxShrinks (const 20)
    . modifyMaxSuccess (const 100)
    . it title
    . hedgehog

spec ∷ Spec
spec = describe "IR Uniquify" do
  let x = Name "x"
      x0 = Name "x0"
      x1 = Name "x1"
      y = Name "y"

  prop "output satisfies the pipeline invariants" do
    e ← forAll Gen.scopedExp
    let uniquified = uniquifyNames (inAllSites e)
    annotateShow uniquified
    lintWellScoped uniquified === []
    lintUniqueBinders uniquified === []

  -- Uniquification only renames binders (and re-points their
  -- references), so the output must be alpha-equivalent to the input.
  prop "is an alpha-renaming" do
    e ← forAll Gen.scopedExp
    let e' = uniquifyNamesInExpr e
    annotateShow e'
    alphaEq e e' === True

  prop "is idempotent" do
    e ← forAll Gen.scopedExp
    let once = uniquifyNamesInExpr e
    uniquifyNamesInExpr once === once

  it "renames a shadowing binder together with its references" do
    -- λx. λx. x — the inner reference resolves to the inner binder.
    uniquifyNamesInExpr
      ( abstraction (paramNamed x) $
          abstraction (paramNamed x) (refLocal x)
      )
      `shouldBe` abstraction
        (paramNamed x)
        (abstraction (paramNamed x1) (refLocal x1))

  it "renames parallel duplicate binders" do
    -- (λx. x) (λx. x): the second λ is in a sibling scope, where no x
    -- is in scope, yet its binder must still be unique within the site.
    let identityAbs = abstraction (paramNamed x) (refLocal x)
    uniquifyNamesInExpr (application identityAbs identityAbs)
      `shouldBe` application
        identityAbs
        (abstraction (paramNamed x0) (refLocal x0))

  it "renames a shadowing Let binder, resolving RHS pre-binding" do
    -- let x = 1 in let x = x in x: the inner RHS's x resolves to the
    -- outer binding (a Standalone RHS does not see its own binder).
    uniquifyNamesInExpr
      ( lets (Standalone (noAnn, x, literalInt 1) :| []) $
          lets
            (Standalone (noAnn, x, refLocal x) :| [])
            (refLocal x)
      )
      `shouldBe` lets
        (Standalone (noAnn, x, literalInt 1) :| [])
        ( lets
            (Standalone (noAnn, x1, refLocal x) :| [])
            (refLocal x1)
        )

  it "renames a shadowing LetValues binder, resolving the RHS pre-binding" do
    -- λx. letValues x = x in x: the RHS's x resolves to the λ binder (a
    -- LetValues RHS does not see its own binders —
    -- Note [Multi-value results]); the body's x to the renamed binder.
    uniquifyNamesInExpr
      ( abstraction (paramNamed x) $
          letValues (paramNamed x :| []) (refLocal x) (refLocal x)
      )
      `shouldBe` abstraction
        (paramNamed x)
        (letValues (paramNamed x1 :| []) (refLocal x) (refLocal x1))

  it "renames self-references inside a shadowing recursive group" do
    -- λx. letrec x = x in x: a member's RHS sees its own group.
    uniquifyNamesInExpr
      ( abstraction (paramNamed x) $
          lets
            (RecursiveGroup ((noAnn, x, refLocal x) :| []) :| [])
            (refLocal x)
      )
      `shouldBe` abstraction
        (paramNamed x)
        ( lets
            (RecursiveGroup ((noAnn, x1, refLocal x1) :| []) :| [])
            (refLocal x1)
        )

  it "preserves member order of recursive groups" do
    -- Member order is the initialization order computed by the
    -- laziness transform (issue #133) — renaming must not disturb it.
    let recGroup =
          RecursiveGroup
            ( (noAnn, x, refLocal y)
                :| [(noAnn, y, refLocal x)]
            )
            :| []
        e = lets recGroup (refLocal y)
    uniquifyNamesInExpr e `shouldBe` e

  it "never mints the runtime lazy factory name" do
    -- See Note [The PSLUA_runtime_lazy coupling]: free references to
    -- the factory stay, and a binder of that name is renamed away so
    -- it cannot capture them.
    let factory = Name runtimeLazyName
        factory0 = Name (runtimeLazyName <> "0")
    uniquifyNamesInExpr (refLocal factory)
      `shouldBe` refLocal factory
    uniquifyNamesInExpr (abstraction (paramNamed factory) (refLocal factory))
      `shouldBe` abstraction (paramNamed factory0) (refLocal factory0)

  it "uniquifies bindings, foreigns, and exports" do
    let shadowing =
          abstraction (paramNamed x) (abstraction (paramNamed x) (refLocal x))
    lintUniqueBinders (uniquifyNames (inAllSites shadowing)) `shouldBe` []

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

inAllSites ∷ Exp → UberModule
inAllSites e =
  UberModule
    { uberModuleBindings = [Standalone (qname, e)]
    , uberModuleForeigns = [(qname, e)]
    , uberModuleExports = [(Name "it", e)]
    }
 where
  qname = QName (moduleNameFromString "Main") (Name "it")
