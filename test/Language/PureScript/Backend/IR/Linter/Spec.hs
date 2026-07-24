module Language.PureScript.Backend.IR.Linter.Spec where

import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( Site (..)
  , Violation (..)
  , lintDanglingImports
  , lintUniqueBinders
  , lintWellApplied
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
  , abstractionN
  , application
  , applicationN
  , ifThenElse
  , letValues
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , values
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

  -- See issue #297: a manufactured reference to a DCE'd binding
  -- compiles to a nil call, so closed modules must resolve every
  -- imported reference.
  describe "DanglingImports" do
    let m = moduleNameFromString "M"
        thereQ = QName m (Name "there")
        goneQ = QName m (Name "gone")
        refThere = refImported m (Name "there")
        refGone = refImported m (Name "gone")

    it "accepts a reference to a top-level binding" do
      lintDanglingImports
        ( (inBinding refThere)
            { uberModuleBindings =
                [ Standalone (itQName, refThere)
                , Standalone (thereQ, literalInt 1)
                ]
            }
        )
        `shouldBe` []

    it "accepts a reference to a foreign" do
      lintDanglingImports
        ((inBinding refThere) {uberModuleForeigns = [(thereQ, literalInt 1)]})
        `shouldBe` []

    it "exempts the Prim marker namespace" do
      lintDanglingImports
        (inBinding (refImported (moduleNameFromString "Prim") (Name "undefined")))
        `shouldBe` []

    it "flags an unresolvable imported reference at every site" do
      lintDanglingImports
        UberModule
          { uberModuleBindings = [Standalone (itQName, refGone)]
          , uberModuleForeigns = [(thereQ, refGone)]
          , uberModuleExports = [(Name "it", refGone)]
          }
        `shouldBe` [ DanglingImport (InBinding itQName) goneQ
                   , DanglingImport (InForeign thereQ) goneQ
                   , DanglingImport (InExport (Name "it")) goneQ
                   ]

    it "reports each dangling name once per site" do
      lintDanglingImports (inBinding (application refGone refGone))
        `shouldBe` [DanglingImport (InBinding itQName) goneQ]

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

  describe "WellApplied" do
    let x = Name "x"
        y = Name "y"
        lam = abstraction (paramNamed x) (refLocal x)
        lam2 =
          abstractionN
            (paramNamed x :| [paramNamed y])
            (refLocal x)
        a = literalInt 1
        b = literalInt 2
        c = literalInt 3

    it "accepts a single-argument application of a lambda" do
      lintWellApplied (inBinding (application lam a)) `shouldBe` []

    it "accepts a multi-argument call with a non-lambda head" do
      lintWellApplied
        (inBinding (applicationN (refLocal (Name "f")) (a :| [b, c])))
        `shouldBe` []

    it "accepts an exactly-saturated application of an n-ary lambda" do
      lintWellApplied (inBinding (applicationN lam2 (a :| [b])))
        `shouldBe` []

    it "flags a lambda applied to more than one argument in one call" do
      lintWellApplied (inBinding (applicationN lam (a :| [b])))
        `shouldBe` [LambdaArityMismatch (InBinding itQName) 1 2]

    it "flags an n-ary lambda applied to too few arguments in one call" do
      -- Lua fills the missing parameter with nil instead of currying.
      lintWellApplied (inBinding (application lam2 a))
        `shouldBe` [LambdaArityMismatch (InBinding itQName) 2 1]

    it "flags a curried lambda applied to several arguments in one call" do
      -- \x → \y → x compiles to nested one-parameter Lua functions, so a
      -- single call passing two arguments to the outer one drops the
      -- second: currying must stay expressed by nesting, not a flat list.
      let curried =
            abstraction
              (paramNamed x)
              (abstraction (paramNamed y) (refLocal x))
      lintWellApplied (inBinding (applicationN curried (a :| [b])))
        `shouldBe` [LambdaArityMismatch (InBinding itQName) 1 2]

    it "descends into call arguments to find nested over-applications" do
      -- A well-formed outer call whose second argument is itself an
      -- over-application: every argument must be visited.
      let nested = applicationN lam (a :| [b])
          outer = applicationN (refLocal (Name "g")) (a :| [nested])
      lintWellApplied (inBinding outer)
        `shouldBe` [LambdaArityMismatch (InBinding itQName) 1 2]

    it "accepts a trailing run of unused parameters" do
      lintWellApplied
        ( inBinding
            ( abstractionN
                (paramNamed x :| [paramUnused, paramUnused])
                (refLocal x)
            )
        )
        `shouldBe` []

    it "flags a named parameter after an unused one" do
      lintWellApplied
        ( inBinding
            (abstractionN (paramUnused :| [paramNamed x]) (refLocal x))
        )
        `shouldBe` [NonTrailingUnusedParam (InBinding itQName)]

    -- See Note [Multi-value results]
    describe "multi-value nodes (#206)" do
      let f = refLocal (Name "f")
          pair = values (a :| [b])
          bindPair = letValues (paramNamed x :| [paramNamed y]) f

      it "accepts a Values in a lambda tail" do
        lintWellApplied (inBinding (abstraction (paramNamed x) pair))
          `shouldBe` []

      it "accepts a Values behind Let bodies and IfThenElse branches" do
        lintWellApplied
          ( inBinding . abstraction (paramNamed x) $
              lets
                (Standalone (noAnn, y, a) :| [])
                (ifThenElse (refLocal x) pair (values (b :| [c])))
          )
          `shouldBe` []

      it "accepts a Values as a LetValues right-hand side" do
        lintWellApplied
          (inBinding (abstraction (paramNamed x) (bindPair (refLocal y))))
          `shouldBe` []

      it "flags a Values in an argument position" do
        lintWellApplied
          (inBinding (application (refLocal (Name "g")) pair))
          `shouldBe` [ValuesOutsideTail (InBinding itQName)]

      it "flags a Values in an IfThenElse condition" do
        lintWellApplied
          ( inBinding . abstraction (paramNamed x) $
              ifThenElse pair a b
          )
          `shouldBe` [ValuesOutsideTail (InBinding itQName)]

      it "flags a Values in a Let grouping right-hand side" do
        -- A grouping RHS is bound to one name, so it is a single-value
        -- slot even inside a multi-value tail.
        lintWellApplied
          ( inBinding . abstraction (paramNamed x) $
              lets (Standalone (noAnn, y, pair) :| []) (refLocal y)
          )
          `shouldBe` [ValuesOutsideTail (InBinding itQName)]

      it "flags a named LetValues binder after an unused one" do
        lintWellApplied
          ( inBinding . abstraction (paramNamed x) $
              letValues (paramUnused :| [paramNamed y]) f (refLocal y)
          )
          `shouldBe` [NonTrailingUnusedParam (InBinding itQName)]

      it "scopes LetValues binders over the body only" do
        -- The binder does not reach the RHS, so an RHS reference to it
        -- is unbound; the body reference is fine.
        let e = letValues (paramNamed y :| []) (refLocal y) (refLocal y)
        unboundLocals e `shouldBe` [y]
