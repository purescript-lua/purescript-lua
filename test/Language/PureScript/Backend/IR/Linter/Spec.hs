module Language.PureScript.Backend.IR.Linter.Spec where

import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( Site (..)
  , Violation (..)
  , lintUberModule
  , unboundLocals
  )
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Grouping (..)
  , abstraction
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , refLocal
  )
import Language.PureScript.Names (runtimeLazyName)
import Test.Hspec (Spec, describe, it, shouldBe)
import Test.Hspec.Hedgehog.Extended (test)

spec ∷ Spec
spec = describe "IR Linter" do
  test "generated well-scoped expressions lint clean" do
    e ← forAll Gen.scopedExp
    unboundLocals e === []

  it "flags an unbound local at every module site" do
    let y = Name "y"
        unbound = refLocal y 0
        qname = QName (moduleNameFromString "Main") (Name "it")
    lintUberModule
      UberModule
        { uberModuleBindings = [Standalone (qname, unbound)]
        , uberModuleForeigns = [(qname, unbound)]
        , uberModuleExports = [(Name "it", unbound)]
        }
      `shouldBe` [ UnboundLocal (InBinding qname) y 0
                 , UnboundLocal (InForeign qname) y 0
                 , UnboundLocal (InExport (Name "it")) y 0
                 ]

  -- See Note [The PSLUA_runtime_lazy coupling] in Language.PureScript.Names:
  -- the laziness transform emits free references to the runtime lazy factory
  -- whose definition only appears as a Lua fixture at codegen.
  it "treats the runtime lazy factory as bound by the runtime" do
    let factory = Name runtimeLazyName
    unboundLocals (refLocal factory 0) `shouldBe` []
    -- …but only the runtime's own binder: deeper indices still dangle.
    unboundLocals (refLocal factory 1) `shouldBe` [(factory, 1)]

  it "counts binders of the referenced name only" do
    let x = Name "x"
        y = Name "y"
    -- \x → \y → x@1 — the y binder must not satisfy x's index 1.
    unboundLocals
      (abstraction (paramNamed x) (abstraction (paramNamed y) (refLocal x 1)))
      `shouldBe` [(x, 1)]

  it "resolves Let references per Note [Sequential scoping of Let bindings]" do
    let x = Name "x"
    -- \x → let x = 1 in x@1: index 1 skips the Let binder onto the λ binder.
    unboundLocals
      ( abstraction (paramNamed x) $
          lets (Standalone (noAnn, x, literalInt 1) :| []) (refLocal x 1)
      )
      `shouldBe` []
    -- let x = 1 in x@1: nothing outside the Let binds x.
    unboundLocals
      (lets (Standalone (noAnn, x, literalInt 1) :| []) (refLocal x 1))
      `shouldBe` [(x, 1)]
    -- A Standalone RHS does not see its own binder…
    unboundLocals
      (lets (Standalone (noAnn, x, refLocal x 0) :| []) (literalInt 1))
      `shouldBe` [(x, 0)]
    -- …but a recursive-group member's RHS sees every member of its group.
    unboundLocals
      ( lets
          (RecursiveGroup ((noAnn, x, refLocal x 0) :| []) :| [])
          (literalInt 1)
      )
      `shouldBe` []
