module Language.PureScript.Backend.IR.Linter.Spec where

import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( Site (..)
  , Violation (..)
  , lintIndicesZero
  , lintUniqueBinders
  , lintWellScoped
  , unboundLocals
  )
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , discardName
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , abstraction
  , application
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , refLocal
  )
import Language.PureScript.Names (runtimeLazyName)
import Test.Hspec (Spec, describe, it, shouldBe)
import Test.Hspec.Hedgehog.Extended (test)

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

itQName ∷ QName
itQName = QName (moduleNameFromString "Main") (Name "it")

inBinding ∷ Exp → UberModule
inBinding e =
  UberModule
    { uberModuleBindings = [Standalone (itQName, e)]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

spec ∷ Spec
spec = describe "IR Linter" do
  test "generated well-scoped expressions lint clean" do
    e ← forAll Gen.scopedExp
    unboundLocals e === []

  it "flags an unbound local at every module site" do
    let y = Name "y"
        unbound = refLocal y 0
        qname = QName (moduleNameFromString "Main") (Name "it")
    lintWellScoped
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

  describe "UniqueBinders" do
    let x = Name "x"
        identityAbs = abstraction (paramNamed x) (refLocal x 0)

    it "flags a shadowing duplicate binder" do
      lintUniqueBinders (inBinding (abstraction (paramNamed x) identityAbs))
        `shouldBe` [DuplicateBinder (InBinding itQName) x]

    it "flags a parallel duplicate binder" do
      lintUniqueBinders (inBinding (application identityAbs identityAbs))
        `shouldBe` [DuplicateBinder (InBinding itQName) x]

    it "does not conflate same-named binders across sites" do
      -- Uniqueness is per top-level entry: two sites may both bind x.
      lintUniqueBinders
        UberModule
          { uberModuleBindings = [Standalone (itQName, identityAbs)]
          , uberModuleForeigns = []
          , uberModuleExports = [(Name "it", identityAbs)]
          }
        `shouldBe` []

    it "exempts the discard binder but flags references to it" do
      let twoDiscards =
            lets
              ( Standalone (noAnn, discardName, literalInt 1)
                  :| [Standalone (noAnn, discardName, literalInt 2)]
              )
              (literalInt 3)
      lintUniqueBinders (inBinding twoDiscards) `shouldBe` []
      lintUniqueBinders (inBinding (refLocal discardName 0))
        `shouldBe` [RefToDiscard (InBinding itQName)]
      -- Occurrences are indistinguishable (no location in the
      -- violation), so several collapse into a single entry per site.
      lintUniqueBinders
        ( inBinding
            (application (refLocal discardName 0) (refLocal discardName 0))
        )
        `shouldBe` [RefToDiscard (InBinding itQName)]

  describe "IndicesZero" do
    let x = Name "x"

    it "flags a local reference with a nonzero index" do
      -- Well-scoped, yet nonzero: λx. λx. x@1.
      lintIndicesZero
        ( inBinding
            ( abstraction
                (paramNamed x)
                (abstraction (paramNamed x) (refLocal x 1))
            )
        )
        `shouldBe` [NonZeroIndex (InBinding itQName) x 1]

    it "accepts index-0 references (even unbound ones)" do
      -- Scoping is WellScoped's business, not this check's.
      lintIndicesZero (inBinding (refLocal x 0)) `shouldBe` []
