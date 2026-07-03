module Language.PureScript.Backend.IR.Linter.Spec where

import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( Site (..)
  , Violation (..)
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
        unbound = refLocal y
        qname = QName (moduleNameFromString "Main") (Name "it")
    lintWellScoped
      UberModule
        { uberModuleBindings = [Standalone (qname, unbound)]
        , uberModuleForeigns = [(qname, unbound)]
        , uberModuleExports = [(Name "it", unbound)]
        }
      `shouldBe` [ UnboundLocal (InBinding qname) y
                 , UnboundLocal (InForeign qname) y
                 , UnboundLocal (InExport (Name "it")) y
                 ]

  -- See Note [The PSLUA_runtime_lazy coupling] in Language.PureScript.Names:
  -- the laziness transform emits free references to the runtime lazy factory
  -- whose definition only appears as a Lua fixture at codegen.
  it "treats the runtime lazy factory as bound by the runtime" do
    let factory = Name runtimeLazyName
    unboundLocals (refLocal factory) `shouldBe` []

  it "tracks bound names per name, not per binder" do
    let x = Name "x"
        y = Name "y"
        z = Name "z"
    -- \x → \y → z — unrelated binders do not bind z.
    unboundLocals
      (abstraction (paramNamed x) (abstraction (paramNamed y) (refLocal z)))
      `shouldBe` [z]

  it "resolves Let references per Note [Sequential scoping of Let bindings]" do
    let x = Name "x"
    -- A Standalone RHS does not see its own binder…
    unboundLocals
      (lets (Standalone (noAnn, x, refLocal x) :| []) (literalInt 1))
      `shouldBe` [x]
    -- …but a recursive-group member's RHS sees every member of its group.
    unboundLocals
      ( lets
          (RecursiveGroup ((noAnn, x, refLocal x) :| []) :| [])
          (literalInt 1)
      )
      `shouldBe` []
    -- The body sees the bindings.
    unboundLocals
      (lets (Standalone (noAnn, x, literalInt 1) :| []) (refLocal x))
      `shouldBe` []

  describe "UniqueBinders" do
    let x = Name "x"
        identityAbs = abstraction (paramNamed x) (refLocal x)

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
      lintUniqueBinders (inBinding (refLocal discardName))
        `shouldBe` [RefToDiscard (InBinding itQName)]
      -- Occurrences are indistinguishable (no location in the
      -- violation), so several collapse into a single entry per site.
      lintUniqueBinders
        ( inBinding
            (application (refLocal discardName) (refLocal discardName))
        )
        `shouldBe` [RefToDiscard (InBinding itQName)]
