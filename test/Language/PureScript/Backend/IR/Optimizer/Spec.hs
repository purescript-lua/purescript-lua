module Language.PureScript.Backend.IR.Optimizer.Spec where

import Data.Map qualified as Map
import Data.Text qualified as Text
import Hedgehog (PropertyT, annotateShow, diff, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Inliner
  ( Annotation (Always, Arity, Never)
  )
import Language.PureScript.Backend.IR.Linker (LinkMode (..))
import Language.PureScript.Backend.IR.Linker qualified as Linker
import Language.PureScript.Backend.IR.Linter
  ( lintUniqueBinders
  , lintWellScoped
  , unboundLocals
  )
import Language.PureScript.Backend.IR.Names
  ( CtorName (..)
  , FieldName (..)
  , Name (..)
  , PropName (..)
  , QName (..)
  , Qualified (..)
  , TyName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Optimizer
  ( CallSiteInlining (SkipCallSites)
  , optimizeModule
  , optimizedExpression
  , optimizedUberModule
  , optimizedUberModuleChecked
  , shareForeignAccessors
  , sinkProjectionIntoLet
  )
import Language.PureScript.Backend.IR.Supply (runSupply)
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (ProductType, SumType)
  , Ann
  , Capture (..)
  , Exp
  , Grouping (..)
  , Module (..)
  , PrimOp (..)
  , RawExp (..)
  , Usage (..)
  , abstraction
  , abstractionN
  , alphaEq
  , application
  , applicationN
  , countFreeRef
  , countFreeRefUsage
  , countFreeRefs
  , ctor
  , ctorId
  , dataArgumentByIndex
  , eq
  , getAnn
  , ifThenElse
  , isLiteral
  , lets
  , literalBool
  , literalFloat
  , literalInt
  , literalObject
  , literalString
  , noAnn
  , objectProp
  , objectUpdate
  , paramNamed
  , paramUnused
  , primBinOp
  , primNot
  , refImported
  , refLocal
  , reflectCtor
  , setAnn
  , pattern EffectRunArg
  )
import Language.PureScript.Backend.IR.Uniquify (uniquifyNamesInExpr)
import Test.Hspec
  ( Spec
  , SpecWith
  , describe
  , expectationFailure
  , it
  , shouldBe
  , shouldSatisfy
  )
import Test.Hspec.Hedgehog (hedgehog, modifyMaxShrinks, modifyMaxSuccess)
import Test.Hspec.Hedgehog.Extended (test)

-- | Like 'test', but runs the property over many generated inputs.
prop ∷ String → PropertyT IO () → SpecWith ()
prop title =
  modifyMaxShrinks (const 20)
    . modifyMaxSuccess (const 100)
    . it title
    . hedgehog

spec ∷ Spec
spec = describe "IR Optimizer" do
  describe "optimizes expressions" do
    test "removes redundant else branch" do
      thenBranch ← forAll Gen.exp
      elseBranch ← forAll Gen.exp
      let ifThenElseStatement = ifThenElse (literalBool True) thenBranch elseBranch
      annotateShow ifThenElseStatement
      thenBranch === optimizedExpression ifThenElseStatement

    test "removes redundant then branch" do
      thenBranch ← forAll Gen.exp
      elseBranch ← forAll Gen.exp
      let ifThenElseStatement = ifThenElse (literalBool False) thenBranch elseBranch
      annotateShow ifThenElseStatement
      elseBranch === optimizedExpression ifThenElseStatement

    test "removes if with alpha-equal branches" do
      -- The branches differ only in binder names, so the condition
      -- cannot influence the result.
      cond ← forAll Gen.name
      let branch param = abstraction (paramNamed param) (refLocal param)
          original =
            ifThenElse
              (refLocal cond)
              (branch (Name "x"))
              (branch (Name "y"))
      optimizedExpression original === branch (Name "x")

    test "eliminates argument if corresponding parameter is unused" do
      body ← forAll Gen.nonRecursiveExp
      arg ← forAll Gen.exp
      let f = abstraction paramUnused body
      body === optimizedExpression (application f arg)

    -- See Note [Eta reduction is unsound]
    test "does not eta-reduce λx. M x to M" do
      param ← forAll Gen.name
      let dict = moduleNameFromString "Dict"
          m =
            application
              (refImported dict (Name "eqList"))
              (refImported dict (Name "eqInt"))
          original = abstraction (paramNamed param) (application m (refLocal param))
      optimizedExpression original === original

  -- Beta reduction must not paste a non-trivial argument into every
  -- occurrence of the parameter, repeating its work at each use site in a
  -- strict language; it let-binds the argument instead.
  -- See Note [Beta reduction and local inlining share an inlining guard]
  describe "beta reduction does not duplicate work (#167)" do
    let m = moduleNameFromString "M"
        x = Name "x"
        -- An application: evaluating it twice would repeat the work.
        nonTrivial = application (refImported m (Name "g")) (literalInt 1)

    it "let-binds a non-trivial argument used more than once" do
      let body = eq (refLocal x) (refLocal x)
          original = application (abstraction (paramNamed x) body) nonTrivial
      optimizedExpression original `shouldBe` let1 x nonTrivial body

    it "still substitutes a trivial reference used more than once" do
      let g = refImported m (Name "g")
          body = eq (refLocal x) (refLocal x)
          original = application (abstraction (paramNamed x) body) g
      optimizedExpression original `shouldBe` eq g g

    it "substitutes a non-trivial argument used exactly once" do
      let original =
            application (abstraction (paramNamed x) (refLocal x)) nonTrivial
      optimizedExpression original `shouldBe` nonTrivial

    it "discards a non-trivial argument that is never used" do
      let original =
            application (abstraction (paramNamed x) (literalInt 7)) nonTrivial
      optimizedExpression original `shouldBe` literalInt 7

  -- The optimizer half of the Effect/ST canonicalization (see
  -- Note [Canonical Effect/ST heads]): a dictionary reference that is
  -- Local inside its defining module at translation time only becomes
  -- Imported once the linker requalifies it, so the same rewrite runs
  -- as an optimizer rule too.
  describe "canonicalizes linker-requalified Effect/ST heads" do
    let cb = moduleNameFromString "Control.Bind"
        eff = moduleNameFromString "Effect"
        cmsi = moduleNameFromString "Control.Monad.ST.Internal"
        bind = refImported cb (Name "bind")
        discard = refImported cb (Name "discard")
        discardUnit = refImported cb (Name "discardUnit")
        purE =
          refImported (moduleNameFromString "Control.Applicative") (Name "pure")
        effBindE = refImported eff (Name "bindE")

    it "rewrites a bind·dictionary pair exposed after linking" do
      optimizedExpression (application bind (refImported eff (Name "bindEffect")))
        `shouldBe` effBindE

    it "rewrites the discard·discardUnit·dictionary triple" do
      optimizedExpression
        ( application
            (application discard discardUnit)
            (refImported cmsi (Name "bindST"))
        )
        `shouldBe` refImported cmsi (Name "bind_")

    it "rewrites a pure·dictionary pair" do
      optimizedExpression
        (application purE (refImported cmsi (Name "applicativeST")))
        `shouldBe` refImported cmsi (Name "pure_")

    it "is idempotent" do
      optimizedExpression effBindE `shouldBe` effBindE

    it "leaves a non-Effect dictionary alone" do
      let original =
            application
              bind
              (refImported (moduleNameFromString "Data.Maybe") (Name "bindMaybe"))
      optimizedExpression original `shouldBe` original

  -- A magic-do effect run (@m $magicDoRun@, see 'isEffectRun') bound by a
  -- Let statement is kept by dead-code elimination even when its binder
  -- is unreferenced, so pasting its RHS into the body leaves two copies —
  -- the surviving statement and the pasted one — and the effect executes
  -- twice.
  describe "local inlining leaves magic-do effect runs in place" do
    it "declines to inline a use-once effect-run binding" do
      let m = moduleNameFromString "M"
          x = Name "x"
          runAct =
            application (refImported m (Name "act")) (EffectRunArg noAnn)
          body = application (refImported m (Name "consume")) (refLocal x)
          original = let1 x runAct body
      optimizedExpression original `shouldBe` original

    it "declines to inline a use-once n-ary worker effect run" do
      -- The late uncurry run (issue #200) absorbs the marker into the
      -- worker call as its trailing argument; the statement is still an
      -- effect run and must stay a statement.
      let m = moduleNameFromString "M"
          x = Name "x"
          runAct =
            applicationN
              (refImported m (Name "act$w"))
              (literalInt 1 :| [EffectRunArg noAnn])
          body = application (refImported m (Name "consume")) (refLocal x)
          original = let1 x runAct body
      optimizedExpression original `shouldBe` original

  -- The n-ary redex — one call binding every parameter of a literal
  -- 'AbsN' (Note [n-ary abstraction]). Reduces only at exact arity;
  -- each pair is decided by the same guard as the unary rule.
  describe "n-ary beta reduction" do
    let m = moduleNameFromString "M"
        x = Name "x"
        y = Name "y"
        nonTrivial = application (refImported m (Name "g")) (literalInt 1)

    it "substitutes every trivial argument of a saturated call" do
      let a = refImported m (Name "a")
          b = refImported m (Name "b")
          body = eq (refLocal x) (refLocal y)
          original =
            applicationN
              (abstractionN (paramNamed x :| [paramNamed y]) body)
              (a :| [b])
      optimizedExpression original `shouldBe` eq a b

    it "let-binds the non-trivial multiply-used argument only" do
      let body = eq (refLocal y) (eq (refLocal x) (refLocal y))
          original =
            applicationN
              (abstractionN (paramNamed x :| [paramNamed y]) body)
              (literalInt 1 :| [nonTrivial])
      optimizedExpression original
        `shouldBe` let1
          y
          nonTrivial
          (eq (refLocal y) (eq (literalInt 1) (refLocal y)))

    it "drops the argument at a ParamUnused position" do
      let original =
            applicationN
              (abstractionN (paramNamed x :| [paramUnused]) (refLocal x))
              (literalInt 1 :| [nonTrivial])
      optimizedExpression original `shouldBe` literalInt 1

    it "does not reduce an under-applied n-ary lambda" do
      -- Ill-formed input ('WellApplied'); the rule must decline rather
      -- than pretend the call curries.
      let original =
            application
              (abstractionN (paramNamed x :| [paramNamed y]) (refLocal x))
              (literalInt 1)
      optimizedExpression original `shouldBe` original

    it "does not reduce a lambda with repeated parameter names" do
      -- Non-GUC input: substituting left to right would steal the
      -- occurrences belonging to the last same-named parameter.
      let original =
            applicationN
              (abstractionN (paramNamed x :| [paramNamed x]) (refLocal x))
              (literalInt 1 :| [literalInt 2])
      optimizedExpression original `shouldBe` original

  describe "folds record-literal projections" do
    let foo = PropName "foo"
        bar = PropName "bar"

    it "projects a field out of a record literal" do
      let original =
            objectProp
              (literalObject [(foo, literalInt 1), (bar, literalInt 2)])
              foo
      optimizedExpression original `shouldBe` literalInt 1

    it "declines when the projected field is absent" do
      -- Unreachable for well-typed IR; the rule must decline rather
      -- than invent a value.
      let original = objectProp (literalObject [(bar, literalInt 2)]) foo
      optimizedExpression original `shouldBe` original

    it "feeds the folded value into sibling rules in one pass" do
      let original =
            eq
              (objectProp (literalObject [(foo, literalInt 1)]) foo)
              (literalInt 1)
      optimizedExpression original `shouldBe` literalBool True

    it "projects a patched field out of a record update" do
      let original =
            objectProp
              ( objectUpdate
                  (refLocal (Name "r"))
                  ((foo, literalInt 3) :| [])
              )
              foo
      optimizedExpression original `shouldBe` literalInt 3

    it "projects through an update that skips the field" do
      -- The update does not patch foo, so the projection reaches
      -- through it into the underlying literal.
      let original =
            objectProp
              ( objectUpdate
                  (literalObject [(foo, literalInt 1), (bar, literalInt 2)])
                  ((bar, literalInt 3) :| [])
              )
              foo
      optimizedExpression original `shouldBe` literalInt 1

    -- A record field can hold an expression whose root annotation is
    -- `Just Always` — the shape the Linker gives foreign accessors (see
    -- Note [Foreign bindings structure emitted by the Linker]). The fold
    -- must not hand that annotation to its result: the result occupies
    -- the projection's position, so it carries the projection's
    -- annotation.
    let dictModule = moduleNameFromString "Dict"
        accessor =
          ObjectProp
            (Just Always)
            (refImported dictModule (Name "foreign"))
            foo

    it "does not leak the field's annotation out of a record literal" do
      let original = objectProp (literalObject [(foo, accessor)]) foo
      getAnn (optimizedExpression original) `shouldBe` Nothing

    it "does not leak the patch's annotation out of a record update" do
      let original =
            objectProp
              (objectUpdate (refLocal (Name "r")) ((foo, accessor) :| []))
              foo
      getAnn (optimizedExpression original) `shouldBe` Nothing

    it "keeps the projection's own annotation on the folded value" do
      let original =
            ObjectProp (Just Never) (literalObject [(foo, accessor)]) foo
      getAnn (optimizedExpression original) `shouldBe` Just Never

    -- The end-to-end manifestation: a leaked `Just Always` makes an
    -- unrelated top-level binding unconditionally inlinable, so it gets
    -- duplicated into every use site and dropped from the bindings. The
    -- field holds an annotated application — non-trivial, so nothing but
    -- a leaked annotation could make `add` inlinable at two use sites (a
    -- projection-shaped field inlines on its own merit through the Deref
    -- tier of Note [Complexity and Capture gate inlining]).
    test "keeps a binding whose RHS folds to an annotated field" do
      let mainModule = moduleNameFromString "Main"
          annotatedCall =
            setAnn
              (Just Always)
              (application (refImported dictModule (Name "mk")) (literalInt 1))
          addExp = objectProp (literalObject [(foo, annotatedCall)]) foo
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [Standalone (QName mainModule (Name "add"), addExp)]
              , uberModuleExports =
                  [ (Name "main1", refImported mainModule (Name "add"))
                  , (Name "main2", refImported mainModule (Name "add"))
                  ]
              }
          optimized = optimizedUberModule original
          addKept =
            [ qn
            | Standalone (qn, _) ← Linker.uberModuleBindings optimized
            , qn == QName mainModule (Name "add")
            ]
      annotateShow optimized
      addKept === [QName mainModule (Name "add")]

  describe "folds case-of-known-constructor (#177)" do
    let maybeMod = moduleNameFromString "Data.Maybe"
        maybeTy = TyName "Maybe"
        justName = CtorName "Just"
        justCtor = ctor SumType maybeMod maybeTy justName [FieldName "value0"]
        just = application justCtor
        justTag = ctorId maybeMod maybeTy justName

        tupleMod = moduleNameFromString "Data.Tuple"
        tupleTy = TyName "Tuple"
        tupleName = CtorName "Tuple"
        tupleCtor =
          ctor
            ProductType
            tupleMod
            tupleTy
            tupleName
            [FieldName "value0", FieldName "value1"]
        tuple a = application (application tupleCtor a)

    it "reduces a saturated sum-type tag read to the tag string" do
      optimizedExpression (reflectCtor (just (literalInt 1)))
        `shouldBe` literalString justTag

    it "reduces a field read to the constructor argument" do
      optimizedExpression (dataArgumentByIndex SumType 0 (just (literalInt 7)))
        `shouldBe` literalInt 7

    it "reads the second field of a saturated product application" do
      optimizedExpression
        (dataArgumentByIndex ProductType 1 (tuple (literalInt 1) (literalInt 2)))
        `shouldBe` literalInt 2

    it "declines a field read whose algebraic type mismatches the ctor's" do
      -- The node's algebraic type decides the runtime slot offset, so a
      -- mismatched read addresses a different slot than the fold would
      -- return; only well-typed reads (matching types) fold.
      let original = dataArgumentByIndex ProductType 0 (just (literalInt 7))
      optimizedExpression original `shouldBe` original

    it "collapses a tag-equality test into its result" do
      -- The payoff cascade: the folded tag meets the surrounding Eq and
      -- constant folding reduces the whole decision-tree test.
      let original = eq (reflectCtor (just (literalInt 1))) (literalString justTag)
      optimizedExpression original `shouldBe` literalBool True

    it "declines a partially applied constructor" do
      -- One argument against a two-field constructor: still a function,
      -- so the field read must not fire.
      let original =
            dataArgumentByIndex
              ProductType
              0
              (application tupleCtor (literalInt 1))
      optimizedExpression original `shouldBe` original

    it "declines a product-type tag read" do
      -- Product constructors carry no tag slot at runtime (a product tag
      -- read aliases the first field), so there is no tag string to fold
      -- to.
      let original = reflectCtor (tuple (literalInt 1) (literalInt 2))
      optimizedExpression original `shouldBe` original

    it "drops the discarded arguments of a field read" do
      -- Only the read field survives; the sibling is gone, not Let-bound.
      optimizedExpression
        ( dataArgumentByIndex
            ProductType
            0
            (tuple (refLocal (Name "a")) (refLocal (Name "b")))
        )
        `shouldBe` refLocal (Name "a")

    -- A discarded field can hold a `Just Always`-annotated accessor (see
    -- the record-projection block); the fold must take the read node's
    -- own annotation, never the argument's, or the result becomes
    -- unconditionally inlinable and duplicates across use sites.
    let dictModule = moduleNameFromString "Dict"
        accessor =
          ObjectProp
            (Just Always)
            (refImported dictModule (Name "foreign"))
            (PropName "value0")

    it "does not leak the kept argument's annotation" do
      let original = dataArgumentByIndex SumType 0 (just accessor)
      getAnn (optimizedExpression original) `shouldBe` Nothing

    it "keeps the read node's own annotation on the folded field" do
      let original = DataArgumentByIndex (Just Never) SumType 0 (just accessor)
      getAnn (optimizedExpression original) `shouldBe` Just Never

    -- Randomized discard-semantics stress (the issue's explicit ask):
    -- across arbitrary arity, algebraic type, and argument content, a
    -- field read folds to exactly its argument with the siblings gone
    -- (no residue), and a sum-type tag read folds to the tag string.
    let trivialArg = Gen.choice [Gen.scalarExp, refLocal <$> Gen.name]

    prop "folds a saturated field read to its argument at any arity" do
      before ← forAll (Gen.list (Range.linear 0 3) trivialArg)
      kept ← forAll trivialArg
      after ← forAll (Gen.list (Range.linear 0 3) trivialArg)
      algTy ← forAll (Gen.element [SumType, ProductType])
      modName ← forAll Gen.moduleName
      ty ← forAll Gen.tyName
      cn ← forAll Gen.ctorName
      let args = before <> [kept] <> after
          fields = FieldName . show <$> [1 .. length args]
          app = foldl' application (ctor algTy modName ty cn fields) args
          index = fromIntegral (length before)
      -- Equality to the kept argument alone proves the siblings are
      -- dropped, not Let-bound or duplicated.
      optimizedExpression (dataArgumentByIndex algTy index app) === kept

    prop "folds a saturated sum-type tag read to the tag string" do
      args ← forAll (Gen.list (Range.linear 0 5) trivialArg)
      modName ← forAll Gen.moduleName
      ty ← forAll Gen.tyName
      cn ← forAll Gen.ctorName
      let fields = FieldName . show <$> [1 .. length args]
          app = foldl' application (ctor SumType modName ty cn fields) args
      optimizedExpression (reflectCtor app) === literalString (ctorId modName ty cn)

  describe "propagates a known constructor through a let (#214)" do
    let m = moduleNameFromString "M"
        maybeMod = moduleNameFromString "Data.Maybe"
        maybeTy = TyName "Maybe"
        justName = CtorName "Just"
        nothingName = CtorName "Nothing"
        justCtor = ctor SumType maybeMod maybeTy justName [FieldName "value0"]
        nothingCtor = ctor SumType maybeMod maybeTy nothingName []
        just = application justCtor
        justTag = ctorId maybeMod maybeTy justName
        nothingTag = ctorId maybeMod maybeTy nothingName

        tupleMod = moduleNameFromString "Data.Tuple"
        tupleTy = TyName "Tuple"
        tupleCtor =
          ctor
            ProductType
            tupleMod
            tupleTy
            (CtorName "Tuple")
            [FieldName "value0", FieldName "value1"]

        -- An application: re-evaluating it would repeat the work, so it is
        -- the shape the field-binder must not duplicate.
        nonTrivial = application (refImported m (Name "g")) (literalInt 1)

        here = refLocal (Name "here")
        gone = refLocal (Name "gone")

    it "folds a tag read through the let and collapses to the live branch" do
      -- The key unlock: with the tag folded the surrounding Eq/if meets
      -- constant folding and the unreachable-branch rules.
      let original =
            let1 (Name "v") nothingCtor $
              ifThenElse
                (eq (literalString nothingTag) (reflectCtor (refLocal (Name "v"))))
                here
                gone
      optimizedExpression original `shouldBe` here

    it "drops the constructor payload when only the tag is read" do
      -- The payload is never read, so it is discarded with the binding,
      -- the same licence the in-place fold has for a field read's siblings.
      let original =
            let1 (Name "v") (just nonTrivial) $
              ifThenElse
                (eq (literalString justTag) (reflectCtor (refLocal (Name "v"))))
                here
                gone
      optimizedExpression original `shouldBe` here

    it "binds a field read at several sites once (no duplication)" do
      -- v's field read twice with a non-trivial argument: the argument is
      -- bound to one field-binder read twice, never copied to each site.
      let original =
            let1 (Name "v") (just nonTrivial) $
              application
                ( application
                    (refImported m (Name "pair"))
                    (dataArgumentByIndex SumType 0 (refLocal (Name "v")))
                )
                (dataArgumentByIndex SumType 0 (refLocal (Name "v")))
          -- The field-binder's name is whatever the fresh-name supply draws;
          -- compare up to alpha-equivalence so the test pins the structure --
          -- one field-binder bound once, read twice -- not the incidental name.
          field = Name "$field0"
          expected =
            let1
              field
              nonTrivial
              ( application
                  (application (refImported m (Name "pair")) (refLocal field))
                  (refLocal field)
              )
      optimizedExpression original `shouldSatisfy` alphaEq expected

    it "declines when the binder is read as a whole value" do
      -- v flows into a function as a whole value, so it cannot be dropped
      -- (nor is it inlinable, so the binding survives untouched).
      let original =
            let1 (Name "v") (just (literalInt 1)) $
              application
                (application (refImported m (Name "pair")) (refLocal (Name "v")))
                (refLocal (Name "v"))
      optimizedExpression original `shouldBe` original

    it "declines a partially applied constructor binding" do
      -- Tuple has two fields; one argument leaves it a function, so the
      -- binding is not a saturated constructor.
      let original =
            let1 (Name "v") (application tupleCtor (literalInt 1)) $
              eq
                (dataArgumentByIndex ProductType 0 (refLocal (Name "v")))
                (dataArgumentByIndex ProductType 0 (refLocal (Name "v")))
      optimizedExpression original `shouldBe` original

    it "collapses an inlined-method match to straight-line code" do
      -- End to end through the checked pipeline: it runs DCE (so the
      -- field-binder inlines and the dropped binding disappears) and lints
      -- every pass's contract, so a GUC or scoping violation from folding
      -- through the Let would fail here rather than pass silently. 'main' is
      -- exported twice so it is not itself inlined away, leaving its
      -- optimized body to inspect (mirrors the leak-guard test above).
      let mainMod = moduleNameFromString "Main"
          body =
            let1 (Name "v") (just (literalInt 1)) $
              ifThenElse
                (eq (literalString justTag) (reflectCtor (refLocal (Name "v"))))
                ( application
                    (refImported mainMod (Name "use"))
                    (dataArgumentByIndex SumType 0 (refLocal (Name "v")))
                )
                nothingCtor
      optimized ←
        either (fail . show) pure . optimizedUberModuleChecked $
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (QName mainMod (Name "main"), body)]
            , uberModuleExports =
                [ (Name "r1", refImported mainMod (Name "main"))
                , (Name "r2", refImported mainMod (Name "main"))
                ]
            }
      let mainBody =
            [ e
            | Standalone (QName _ (Name "main"), e) ←
                Linker.uberModuleBindings optimized
            ]
      mainBody
        `shouldBe` [application (refImported mainMod (Name "use")) (literalInt 1)]

    prop "eliminates the binding without growing the reference multiset" do
      -- Across scalar payloads, folding drops v (proof the rule fired: with
      -- the constructor Let-bound, nothing else can) and never invents or
      -- multiplies a free reference.
      payload ← forAll Gen.scalarExp
      let original =
            let1 (Name "v") (just payload) $
              ifThenElse
                (eq (literalString justTag) (reflectCtor (refLocal (Name "v"))))
                ( application
                    (refImported m (Name "use"))
                    (dataArgumentByIndex SumType 0 (refLocal (Name "v")))
                )
                gone
          optimized = optimizedExpression original
      countFreeRef (Local (Name "v")) optimized === 0
      Map.isSubmapOfBy (<=) (countFreeRefs optimized) (countFreeRefs original)
        === True

    prop "declines an out-of-range field read, staying well-scoped" do
      -- A DataArgumentByIndex past the constructor's arity reads no existing
      -- field: folding it would mint a fresh field-binder the (saturated)
      -- argument list cannot bind, then drop the ctor binding, stranding both.
      -- The rule must decline and leave the term well-scoped. Well-typed CoreFn
      -- never indexes past the arity, so the shape is fuzzed structurally --
      -- the arity is random and the index may exceed it -- and the oracle is
      -- well-scopedness (a stranded binder shows up as an unbound local). This
      -- is the guard the reviewer had to point out by hand; the property now
      -- exercises it.
      arity ← forAll (Gen.int (Range.linear 0 3))
      index ← forAll (Gen.integral (Range.linear 0 5))
      let fields =
            [FieldName (Text.pack ("value" <> show k)) | k ← [0 .. arity - 1]]
          ctorApp =
            foldl'
              application
              (ctor SumType m (TyName "T") (CtorName "K") fields)
              (replicate arity (literalInt 1))
          original =
            let1 (Name "v") ctorApp $
              dataArgumentByIndex SumType index (refLocal (Name "v"))
      unboundLocals (optimizedExpression original) === []

    it "resolves a let-bound constructor worker reference, then folds (#180)" do
      -- A user-written `Just x` compiles to `App (Ref Data.Maybe.Just) x`: a
      -- reference to the top-level constructor worker, whose RHS is a bare
      -- 'Ctor' node rather than a lambda, so 'inlineSaturatedCall' leaves it in
      -- place (pasting it would only rebuild the same value the reference
      -- already denotes, more deeply nested). Unless the fold resolves the
      -- reference through the inline environment, the tag test an inlined bind
      -- introduces never folds and the collapsed monadic chain stays a
      -- deeply-nested if/let tree that overflows Lua's parser-nesting cap
      -- (issue #180 -- the shape 'Golden.LongEitherBind' exercises end to end).
      --
      -- The worker is referenced twice (the export 'mkJust' keeps a second
      -- use) so whole-binding inlining cannot fold it away as used-once and
      -- hand the direct-'Ctor' path a constructor node -- which would mask the
      -- reference resolution this test pins. Runs through the checked pipeline
      -- (which populates the environment from the module's own bindings), with
      -- 'main' exported twice so it is not inlined away, leaving its body to
      -- inspect. Without the resolution the body is the whole undecided
      -- if/let; with it, the live branch.
      let mainMod = moduleNameFromString "Main"
          body =
            let1
              (Name "v")
              (application (refImported maybeMod (Name "Just")) (literalInt 1))
              $ ifThenElse
                (eq (literalString justTag) (reflectCtor (refLocal (Name "v"))))
                ( application
                    (refImported mainMod (Name "use"))
                    (dataArgumentByIndex SumType 0 (refLocal (Name "v")))
                )
                nothingCtor
      optimized ←
        either (fail . show) pure . optimizedUberModuleChecked $
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [ Standalone (QName maybeMod (Name "Just"), justCtor)
                , Standalone (QName mainMod (Name "main"), body)
                ]
            , uberModuleExports =
                [ (Name "r1", refImported mainMod (Name "main"))
                , (Name "r2", refImported mainMod (Name "main"))
                , (Name "mkJust", refImported maybeMod (Name "Just"))
                ]
            }
      let mainBody =
            [ e
            | Standalone (QName _ (Name "main"), e) ←
                Linker.uberModuleBindings optimized
            ]
      mainBody
        `shouldBe` [application (refImported mainMod (Name "use")) (literalInt 1)]

  describe "does not duplicate a binding a sibling grouping reads" do
    let m = moduleNameFromString "M"

    prop "keeps a non-trivial binding a later grouping's RHS references" do
      -- Regression: 'inlineLocalBinding' counted a binder's uses in the Let
      -- body only, missing a later grouping's RHS -- which sequential scoping
      -- lets name an earlier binder (Note [Sequential scoping of Let
      -- bindings]). A non-trivial binding read once in the body and once in a
      -- sibling RHS was then inlined into the body, evaluating its RHS a second
      -- time and duplicating any effect it performs (e.g. allocating a fresh
      -- mutable Ref, splitting one cell into two). Only the payload is random;
      -- the RHS is an application (never inlinable) whose free references a
      -- second copy would multiply, so the free-reference multiset must not
      -- grow (as with FloatIn and the #177 fold, optimization only shrinks it).
      payload ← forAll Gen.scalarExp
      let rhs = application (refImported m (Name "mk")) payload
          original =
            lets
              ( Standalone (noAnn, Name "r", rhs)
                  :| [ Standalone
                         ( noAnn
                         , Name "s"
                         , application
                             (refImported m (Name "use"))
                             (refLocal (Name "r"))
                         )
                     ]
              )
              (application (refImported m (Name "consume")) (refLocal (Name "r")))
          optimized = optimizedExpression original
      annotateShow optimized
      Map.isSubmapOfBy (<=) (countFreeRefs optimized) (countFreeRefs original)
        === True

  -- See Note [Folding primops follows Lua 5.1] in the optimizer.
  describe "folds primops (#178)" do
    it "folds integer arithmetic exactly" do
      optimizedExpression (primBinOp PrimAdd (literalInt 2) (literalInt 3))
        `shouldBe` literalInt 5
      optimizedExpression (primBinOp PrimSub (literalInt 2) (literalInt 3))
        `shouldBe` literalInt (-1)
      optimizedExpression (primBinOp PrimMul (literalInt 6) (literalInt 7))
        `shouldBe` literalInt 42

    it "bails on integer results beyond ±2^53" do
      let big = 2 ^ (53 ∷ Int)
          original = primBinOp PrimAdd (literalInt big) (literalInt 1)
      optimizedExpression original `shouldBe` original

    it "folds integer modulo with the sign of the divisor (Lua 5.1)" do
      optimizedExpression (primBinOp PrimMod (literalInt 7) (literalInt 3))
        `shouldBe` literalInt 1
      -- Sign follows the divisor, unlike C's % and Haskell's rem.
      optimizedExpression (primBinOp PrimMod (literalInt (-5)) (literalInt 3))
        `shouldBe` literalInt 1
      optimizedExpression (primBinOp PrimMod (literalInt 5) (literalInt (-3)))
        `shouldBe` literalInt (-1)

    it "leaves modulo by zero to the runtime" do
      let original = primBinOp PrimMod (literalInt 5) (literalInt 0)
      optimizedExpression original `shouldBe` original

    it "folds float arithmetic in double semantics" do
      optimizedExpression (primBinOp PrimAdd (literalFloat 1.5) (literalFloat 2.0))
        `shouldBe` literalFloat 3.5
      optimizedExpression (primBinOp PrimDiv (literalFloat 5.0) (literalFloat 2.0))
        `shouldBe` literalFloat 2.5

    it "leaves a non-finite float result to the runtime" do
      let original = primBinOp PrimDiv (literalFloat 1.0) (literalFloat 0.0)
      optimizedExpression original `shouldBe` original

    it "folds string concatenation" do
      optimizedExpression
        (primBinOp PrimConcat (literalString "foo") (literalString "bar"))
        `shouldBe` literalString "foobar"

    it "folds numeric comparisons" do
      optimizedExpression (primBinOp PrimLt (literalInt 2) (literalInt 3))
        `shouldBe` literalBool True
      optimizedExpression (primBinOp PrimGe (literalInt 3) (literalInt 3))
        `shouldBe` literalBool True
      optimizedExpression (primBinOp PrimGt (literalFloat 1.0) (literalFloat 2.0))
        `shouldBe` literalBool False

    it "does not fold string comparisons (bytes vs Text)" do
      let original = primBinOp PrimLt (literalString "a") (literalString "b")
      optimizedExpression original `shouldBe` original

    it "folds boolean and/or and not" do
      optimizedExpression (primBinOp PrimAnd (literalBool True) (literalBool False))
        `shouldBe` literalBool False
      optimizedExpression (primBinOp PrimOr (literalBool True) (literalBool False))
        `shouldBe` literalBool True
      optimizedExpression (primNot (literalBool True))
        `shouldBe` literalBool False

    it "collapses a known-boolean operand of and/or (short-circuit)" do
      let x = refLocal (Name "x")
      optimizedExpression (primBinOp PrimAnd (literalBool True) x) `shouldBe` x
      optimizedExpression (primBinOp PrimAnd (literalBool False) x)
        `shouldBe` literalBool False
      optimizedExpression (primBinOp PrimOr (literalBool True) x)
        `shouldBe` literalBool True
      optimizedExpression (primBinOp PrimOr (literalBool False) x) `shouldBe` x

    it "folds bottom-up through nested primops" do
      let original =
            primBinOp
              PrimAdd
              (primBinOp PrimMul (literalInt 2) (literalInt 3))
              (literalInt 4)
      optimizedExpression original `shouldBe` literalInt 10

    it "leaves a primop over non-literals alone" do
      let original = primBinOp PrimAdd (refLocal (Name "x")) (literalInt 1)
      optimizedExpression original `shouldBe` original

  describe "simplifies boolean ifs (#178)" do
    let cond = primBinOp PrimLt (refLocal (Name "a")) (refLocal (Name "b"))

    it "reduces if p then True else False to p" do
      optimizedExpression (ifThenElse cond (literalBool True) (literalBool False))
        `shouldBe` cond

    it "reduces if p then False else True to not p" do
      optimizedExpression (ifThenElse cond (literalBool False) (literalBool True))
        `shouldBe` primNot cond

    it "flips a negated condition, swapping the branches" do
      let a = refLocal (Name "a")
          b = refLocal (Name "b")
      optimizedExpression (ifThenElse (primNot (refLocal (Name "p"))) a b)
        `shouldBe` ifThenElse (refLocal (Name "p")) b a

    it "normalises if not p then False else True to p (flip then reduce)" do
      optimizedExpression
        (ifThenElse (primNot cond) (literalBool False) (literalBool True))
        `shouldBe` cond

    it "normalises if not p then True else False to not p" do
      optimizedExpression
        (ifThenElse (primNot cond) (literalBool True) (literalBool False))
        `shouldBe` primNot cond

    it "eliminates a double negation" do
      optimizedExpression (primNot (primNot cond)) `shouldBe` cond

    it "still collapses a literal condition through the unreachable rule" do
      optimizedExpression
        (ifThenElse (literalBool True) (literalBool False) (literalBool True))
        `shouldBe` literalBool False

  describe "inlines expressions" do
    test "inlines literals" do
      name ← forAll Gen.name
      inlinee ← forAll Gen.scalarExp
      let original = let1 name inlinee (refLocal name)
          expected = let1 name inlinee inlinee
      optimizedExpression original === expected

    test "inlines references" do
      name ← forAll Gen.name
      -- A reference to the binding's own name is the one reference that
      -- must NOT be inlined (see the self-inlining test below), so the
      -- inlinee is drawn from the other names.
      inlinee ← refLocal <$> forAll (mfilter (/= name) Gen.name)
      let original = let1 name inlinee (refLocal name)
          expected = let1 name inlinee inlinee
      optimizedExpression original === expected

    -- Regression: substituting @x := x@ is a textual no-op, so the
    -- occurrence count of @x@ never reaches zero and an unguarded rule
    -- keeps firing forever under the driver's repeat-until-Nothing
    -- (caught by CI hanging: the generator above draws the same name
    -- for binder and inlinee with probability 1/7). Such input is
    -- outside the pipeline's GUC domain — under unique binders a
    -- Standalone RHS cannot see its own binder — so the rule must
    -- decline, not loop.
    it "declines to inline a self-referential binding" do
      let x = Name "x"
          original = let1 x (refLocal x) (refLocal x)
      optimizedExpression original `shouldBe` original

    test "inlines expressions referenced once" do
      name ← forAll Gen.name
      inlinee ← forAll $ fmap optimizedExpression do
        -- No self-reference: inlining a binding whose RHS mentions its
        -- own name is declined by the optimizer (non-GUC input).
        mfilter
          ( \e →
              not (isRef e || isLiteral e)
                && countFreeRef (Local name) e == 0
          )
          Gen.exp
      let body = refLocal name
          original = let1 name inlinee body
          expected = let1 name inlinee inlinee
      annotateShow body
      -- The inserted copy gets fresh binder names ('substituteCopyM'
      -- freshens every insertion), so compare up to alpha-equivalence.
      diff (optimizedExpression original) alphaEq expected

    test "doesn't inline expressions referenced more than once" do
      name ← forAll Gen.name
      inlinee ← forAll $ Gen.choice [Gen.exception, Gen.ctor]
      let original =
            let1 name inlinee $
              application (refLocal name) (refLocal name)
      annotateShow original
      optimizedExpression original === original

  describe "respects @inline never (issue #131)" do
    test "keeps a never-annotated top-level binding instead of inlining it" do
      let mainModule = moduleNameFromString "Main"
          -- foo = (1 == 1) with `@inline never`. Constant folding rewrites the
          -- root to `true` (dropping the annotation) and foo is used once, so
          -- without a name-based veto it would be inlined away.
          fooExp = Eq (Just Never) (literalInt 1) (literalInt 1)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [Standalone (QName mainModule (Name "foo"), fooExp)]
              , uberModuleExports =
                  [(Name "main", refImported mainModule (Name "foo"))]
              }
          optimized = optimizedUberModule original
          fooKept =
            [ qn
            | Standalone (qn, _) ← Linker.uberModuleBindings optimized
            , qn == QName mainModule (Name "foo")
            ]
      annotateShow optimized
      fooKept === [QName mainModule (Name "foo")]

  describe "keeps a bare-Ref alias to an @inline always binding (#171)" do
    test "the alias stays the single materialization point" do
      let semiringModule = moduleNameFromString "Data.Semiring"
          mainModule = moduleNameFromString "Main"
          intAddName = QName semiringModule (Name "intAdd")
          addName = QName mainModule (Name "add")
          -- The shape ForeignLift gives a lifted foreign: a lambda marked
          -- @inline always@ so its call sites beta-reduce. Unary, so the
          -- uncurry split leaves it alone and the test sees only the
          -- alias interaction.
          liftedIntAdd =
            setAnn (Just Always) . abstraction (paramNamed (Name "x")) $
              primBinOp PrimAdd (refLocal (Name "x")) (refLocal (Name "x"))
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [ Standalone (intAddName, liftedIntAdd)
                  , Standalone
                      (addName, refImported semiringModule (Name "intAdd"))
                  ]
              , uberModuleExports =
                  [ (Name "main1", refImported mainModule (Name "add"))
                  , (Name "main2", refImported mainModule (Name "add"))
                  ]
              }
      optimized ←
        either (fail . show) pure (optimizedUberModuleChecked original)
      annotateShow optimized
      -- Dissolving the alias would take the Always target's use sites
      -- from one to two right before Always pastes its body into every
      -- one of them. Instead the alias survives — the body materializes
      -- once, in the alias — and both exports keep referencing it.
      [qn | Standalone (qn, _) ← Linker.uberModuleBindings optimized]
        === [addName]
      Linker.uberModuleExports optimized
        === [ (Name "main1", refImported mainModule (Name "add"))
            , (Name "main2", refImported mainModule (Name "add"))
            ]
      -- The Always directive is spent on the paste: the body
      -- materialized into the alias carries no annotation, so nothing
      -- downstream can mistake the alias for a directed binding.
      let aliasAnns =
            [ getAnn rhs
            | Standalone (qn, rhs) ← Linker.uberModuleBindings optimized
            , qn == addName
            ]
      aliasAnns === [Nothing]

    test "a use-once alias to an @inline always binding still dissolves" do
      -- The veto guards multi-use aliases only: at a single use site the
      -- dissolution is a relocation (the target's site count stays one),
      -- so the alias collapses and the body lands at the one site, its
      -- annotation spent.
      let semiringModule = moduleNameFromString "Data.Semiring"
          mainModule = moduleNameFromString "Main"
          liftedIntAdd =
            setAnn (Just Always) . abstraction (paramNamed (Name "x")) $
              primBinOp PrimAdd (refLocal (Name "x")) (refLocal (Name "x"))
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [ Standalone
                      (QName semiringModule (Name "intAdd"), liftedIntAdd)
                  , Standalone
                      ( QName mainModule (Name "add")
                      , refImported semiringModule (Name "intAdd")
                      )
                  ]
              , uberModuleExports =
                  [(Name "main1", refImported mainModule (Name "add"))]
              }
      optimized ←
        either (fail . show) pure (optimizedUberModuleChecked original)
      annotateShow optimized
      Linker.uberModuleBindings optimized === []
      let exportNames = fst <$> Linker.uberModuleExports optimized
      exportNames === [Name "main1"]
      for_ (Linker.uberModuleExports optimized) \(_name, body) →
        diff body alphaEq (setAnn Nothing liftedIntAdd)

  describe "respects @inline always after a rewrite drops it (#171)" do
    test "dissolves a fold-stripped always binding into every use site" do
      -- foo = @inline always (if true then f 1 else g 2). The
      -- unreachable-else fold rewrites the root to `f 1`, dropping the
      -- annotation; the policy keys off the pristine name, so foo still
      -- dissolves into both use sites — the @inline always mirror of the
      -- "respects @inline never (issue #131)" test above.
      let mainModule = moduleNameFromString "Main"
          ext = moduleNameFromString "Ext"
          thenB = application (refImported ext (Name "f")) (literalInt 1)
          elseB = application (refImported ext (Name "g")) (literalInt 2)
          fooExp =
            setAnn (Just Always) (ifThenElse (literalBool True) thenB elseB)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [Standalone (QName mainModule (Name "foo"), fooExp)]
              , uberModuleExports =
                  [ (Name "main1", refImported mainModule (Name "foo"))
                  , (Name "main2", refImported mainModule (Name "foo"))
                  ]
              }
      optimized ←
        either (fail . show) pure (optimizedUberModuleChecked original)
      annotateShow optimized
      Linker.uberModuleBindings optimized === []
      Linker.uberModuleExports optimized
        === [(Name "main1", thenB), (Name "main2", thenB)]

  describe "gates inlining by Complexity and Capture (issue #231)" do
    let main' = moduleNameFromString "Main"
        ext = moduleNameFromString "Ext"
        checked = either (fail . show) pure . optimizedUberModuleChecked
        -- λx. x + 1 — closed, well under any inlining budget.
        incName = Name "f"
        incExpr =
          abstraction (paramNamed (Name "x")) $
            primBinOp PrimAdd (refLocal (Name "x")) (literalInt 1)

    test "inlines a multi-use projection binding (Deref tier)" do
      let dName = QName main' (Name "d")
          dExpr = objectProp (refImported ext (Name "tbl")) (PropName "f")
          dRef = refImported main' (Name "d")
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = [Standalone (dName, dExpr)]
              , uberModuleExports =
                  [(Name "main", application (application dRef dRef) dRef)]
              }
      optimized ← checked original
      annotateShow optimized
      -- The Deref tier pastes the read at every site, so the top-level
      -- binding is gone; the CSE pass (#183) then rebinds the pasted
      -- read locally, within the one body that repeats it.
      Linker.uberModuleBindings optimized === []
      let cseRef = refLocal (Name "$cse0")
      Linker.uberModuleExports optimized
        === [
              ( Name "main"
              , let1 (Name "$cse0") dExpr $
                  application (application cseRef cseRef) cseRef
              )
            ]

    test "keeps a multi-use non-trivial binding shared across branches" do
      let hName = QName main' (Name "h")
          hExpr = application (refImported ext (Name "g")) (literalInt 1)
          hRef = refImported main' (Name "h")
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = [Standalone (hName, hExpr)]
              , uberModuleExports =
                  [
                    ( Name "main"
                    , ifThenElse
                        (refImported ext (Name "cond"))
                        (application hRef (literalInt 1))
                        (application hRef (literalInt 2))
                    )
                  ]
              }
      optimized ← checked original
      annotateShow optimized
      [qn | Standalone (qn, _) ← Linker.uberModuleBindings optimized]
        === [hName]

    it "substitutes a small closed lambda used twice under no closure" do
      let original =
            let1 incName incExpr $
              primBinOp
                PrimAdd
                (application (refLocal incName) (literalInt 1))
                (application (refLocal incName) (literalInt 2))
      optimizedExpression original
        `shouldSatisfy` alphaEq (let1 incName incExpr (literalInt 5))

    it "beta-reduces a small closed lambda argument used twice" do
      let body =
            primBinOp
              PrimAdd
              (application (refLocal incName) (literalInt 1))
              (application (refLocal incName) (literalInt 2))
          original = application (abstraction (paramNamed incName) body) incExpr
      optimizedExpression original `shouldSatisfy` alphaEq (literalInt 5)

    it "refuses to duplicate a lambda into a closure" do
      let original =
            let1 incName incExpr $
              abstraction (paramNamed (Name "y")) $
                primBinOp
                  PrimAdd
                  (application (refLocal incName) (literalInt 1))
                  (application (refLocal incName) (refLocal (Name "y")))
      optimizedExpression original `shouldSatisfy` alphaEq original

    describe "countFreeRefUsage" do
      let freeQ = Imported ext (Name "free")
          freeRef = refImported ext (Name "free")

      it "reports CaptureNone at an unconditional use" do
        countFreeRefUsage freeQ (application freeRef (literalInt 1))
          `shouldBe` Usage 1 CaptureNone

      it "raises to CaptureBranch in a branch arm, not in the condition" do
        countFreeRefUsage
          freeQ
          (ifThenElse (eq freeRef (literalInt 0)) freeRef (literalInt 2))
          `shouldBe` Usage 2 CaptureBranch

      it "raises to CaptureClosure under a lambda" do
        countFreeRefUsage freeQ (abstraction paramUnused freeRef)
          `shouldBe` Usage 1 CaptureClosure

      it "keeps CaptureClosure the ceiling under branch-in-lambda nesting" do
        countFreeRefUsage
          freeQ
          ( ifThenElse
              (literalBool True)
              (abstraction paramUnused freeRef)
              (literalInt 2)
          )
          `shouldBe` Usage 1 CaptureClosure

      it "does not count shadowed locals" do
        countFreeRefUsage
          (Local (Name "x"))
          (abstraction (paramNamed (Name "x")) (refLocal (Name "x")))
          `shouldBe` Usage 0 CaptureNone

      prop "total agrees with countFreeRef" do
        e ← forAll Gen.scopedExp
        let refs = Map.toList (countFreeRefs e)
        annotateShow refs
        for_ refs \(qn, n) → usageTotal (countFreeRefUsage qn e) === n

  -- What a worker/wrapper split turns into is decided by the passes
  -- downstream of the uncurrying pass — the post-uncurry optimize+dce
  -- fixpoint drops dead wrappers and inlines use-once workers — so
  -- these run the whole checked pipeline and assert the final shape.
  describe "composes uncurrying with inlining and DCE (issue #24)" do
    let mainModule = moduleNameFromString "Main"
        extern = moduleNameFromString "Extern"
        g = refImported extern (Name "g")
        fName = QName mainModule (Name "f")
        fRef = refImported mainModule (Name "f")
        -- λa. λb. g a b — non-foldable, so every shape survives on
        -- its own merit.
        fDef =
          abstraction (paramNamed (Name "a")) $
            abstraction (paramNamed (Name "b")) $
              application
                (application g (refLocal (Name "a")))
                (refLocal (Name "b"))
        saturated x y =
          application (application fRef (literalInt x)) (literalInt y)
        checked = either (fail . show) pure . optimizedUberModuleChecked
        namesOf uber =
          [ name
          | Standalone (QName _ (Name name), _) ←
              Linker.uberModuleBindings uber
          ]

    it "drops the wrapper once every site calls the worker directly" do
      -- Two saturated sites and no other use: the split sends both to
      -- f$w, the wrapper loses its last reference, and the post-uncurry
      -- fixpoint removes it. The worker (used twice) stays a shared
      -- binding.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (fName, fDef)]
            , uberModuleExports =
                [(Name "main1", saturated 1 2), (Name "main2", saturated 3 4)]
            }
      namesOf optimized `shouldBe` ["f$w"]

    it "leaves no residue for a used-once function" do
      -- A single saturated site: the use-once inliner claims the whole
      -- binding (before or after the split, either path must end the
      -- same), and beta reduction pastes the body into the site.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (fName, fDef)]
            , uberModuleExports = [(Name "main", saturated 1 2)]
            }
      Linker.uberModuleBindings optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [
                     ( Name "main"
                     , application (application g (literalInt 1)) (literalInt 2)
                     )
                   ]

    it "keeps an exported function curried when its saturated consumer dies" do
      -- The only saturated site sits in a binding unreachable from the
      -- exports: DCE removes it before the uncurry pass measures sites,
      -- so the exported name must come out unsplit — alpha-equal to the
      -- original curried definition, with no worker left anywhere.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [ Standalone (fName, fDef)
                , Standalone (QName mainModule (Name "dead"), saturated 1 2)
                ]
            , uberModuleExports = [(Name "main1", fRef), (Name "main2", fRef)]
            }
      filter ("$w" `Text.isSuffixOf`) (namesOf optimized) `shouldBe` []
      case [ e
           | Standalone (q, e) ← Linker.uberModuleBindings optimized
           , q == fName
           ] of
        [e] → e `shouldSatisfy` (`alphaEq` fDef)
        es → expectationFailure ("expected exactly one f binding: " <> show es)

    it "lets @inline always claim the binding before the split" do
      -- An Always-annotated standalone binding is pasted at every
      -- occurrence by the first optimize+dce fixpoint, so the uncurry
      -- pass never sees it: the pragma wins over the split. The checked
      -- pipeline must stay clean through that interaction — the
      -- saturated paste beta-reduces away, the partial one becomes a
      -- manifest lambda, and neither the name nor a worker survives.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, setAnn (Just Always) fDef)]
            , uberModuleExports =
                [ (Name "main1", saturated 1 2)
                , (Name "main2", application fRef (literalInt 5))
                ]
            }
      namesOf optimized `shouldBe` []
      case Linker.uberModuleExports optimized of
        [(Name "main1", e1), (Name "main2", e2)] → do
          e1
            `shouldBe` application
              (application g (literalInt 1))
              (literalInt 2)
          e2
            `shouldSatisfy` ( `alphaEq`
                                abstraction
                                  (paramNamed (Name "b"))
                                  ( application
                                      (application g (literalInt 5))
                                      (refLocal (Name "b"))
                                  )
                            )
        es → expectationFailure ("unexpected exports: " <> show es)

  describe "honours @inline arity=N directives (issue #232)" do
    let mainModule = moduleNameFromString "Main"
        extern = moduleNameFromString "Extern"
        g = refImported extern (Name "g")
        fName = QName mainModule (Name "f")
        fRef = refImported mainModule (Name "f")
        -- λa. λb. g a b — non-foldable, curried.
        fDef =
          abstraction (paramNamed (Name "a")) $
            abstraction (paramNamed (Name "b")) $
              application
                (application g (refLocal (Name "a")))
                (refLocal (Name "b"))
        applied2 x y =
          application (application fRef (literalInt x)) (literalInt y)
        checked = either (fail . show) pure . optimizedUberModuleChecked
        namesOf uber =
          [ name
          | Standalone (QName _ (Name name), _) ←
              Linker.uberModuleBindings uber
          ]

    it "inlines at sites applied to N arguments" do
      -- Two saturated sites (so the use-once path cannot claim the
      -- binding): both collapse to direct g calls and f is collected.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, setAnn (Just (Arity 2)) fDef)]
            , uberModuleExports =
                [(Name "main1", applied2 1 2), (Name "main2", applied2 3 4)]
            }
      namesOf optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [
                     ( Name "main1"
                     , application (application g (literalInt 1)) (literalInt 2)
                     )
                   ,
                     ( Name "main2"
                     , application (application g (literalInt 3)) (literalInt 4)
                     )
                   ]

    it "keeps the binding a reference at an under-applied site" do
      -- One single-argument site: below the directed arity nothing may
      -- paste — not even the use-once whole-binding path.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, setAnn (Just (Arity 2)) fDef)]
            , uberModuleExports =
                [(Name "main", application fRef (literalInt 1))]
            }
      namesOf optimized `shouldBe` ["f"]
      Linker.uberModuleExports optimized
        `shouldBe` [(Name "main", application fRef (literalInt 1))]

    it "inlines at a site applied to more than N arguments" do
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, setAnn (Just (Arity 1)) fDef)]
            , uberModuleExports =
                [(Name "main1", applied2 1 2), (Name "main2", applied2 3 4)]
            }
      namesOf optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [
                     ( Name "main1"
                     , application (application g (literalInt 1)) (literalInt 2)
                     )
                   ,
                     ( Name "main2"
                     , application (application g (literalInt 3)) (literalInt 4)
                     )
                   ]

    it "bypasses the size budget at a directed site" do
      -- λa. a + 1 + 2 + … — far over 'inlineSizeBudget', so only the
      -- directive can paste it. After the paste, constant folding
      -- collapses each export to a literal.
      let bigDef =
            abstraction (paramNamed (Name "a")) $
              foldl'
                (\acc i → primBinOp PrimAdd acc (literalInt i))
                (refLocal (Name "a"))
                [1 .. 40]
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, setAnn (Just (Arity 1)) bigDef)]
            , uberModuleExports =
                [ (Name "main1", application fRef (literalInt 0))
                , (Name "main2", application fRef (literalInt 100))
                ]
            }
      namesOf optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "main1", literalInt 820)
                   , (Name "main2", literalInt 920)
                   ]

    it "pastes a non-lambda definition at a directed site" do
      -- h = g 1 — a partial application, not a manifest lambda. The
      -- directive pastes it anyway; duplicated work is the user's call.
      let hName = QName mainModule (Name "h")
          hRef = refImported mainModule (Name "h")
          hDef = application g (literalInt 1)
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (hName, setAnn (Just (Arity 1)) hDef)]
            , uberModuleExports =
                [ (Name "main1", application hRef (literalInt 2))
                , (Name "main2", application hRef (literalInt 3))
                ]
            }
      namesOf optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [
                     ( Name "main1"
                     , application (application g (literalInt 1)) (literalInt 2)
                     )
                   ,
                     ( Name "main2"
                     , application (application g (literalInt 1)) (literalInt 3)
                     )
                   ]

    it "keeps an arity-marked binding out of the uncurry split" do
      -- Directed arity above every site's argument count: no site
      -- pastes, and the split must not steal the name's call sites
      -- either — no worker may appear.
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, setAnn (Just (Arity 3)) fDef)]
            , uberModuleExports =
                [(Name "main1", applied2 1 2), (Name "main2", applied2 3 4)]
            }
      namesOf optimized `shouldBe` ["f"]
      Linker.uberModuleExports optimized
        `shouldBe` [(Name "main1", applied2 1 2), (Name "main2", applied2 3 4)]

  describe "honours accessor-form directives (issue #232)" do
    let mainModule = moduleNameFromString "Main"
        extern = moduleNameFromString "Extern"
        g = refImported extern (Name "g")
        m = PropName "m"
        pad = PropName "pad"
        checked = either (fail . show) pure . optimizedUberModuleChecked
        namesOf uber =
          [ name
          | Standalone (QName _ (Name name), _) ←
              Linker.uberModuleBindings uber
          ]
        addChain ∷ Exp → [Integer] → Exp
        addChain = foldl' \acc i → primBinOp PrimAdd acc (literalInt i)
        dictName = QName mainModule (Name "dict")
        dictRef = refImported mainModule (Name "dict")
        fName = QName mainModule (Name "f")
        fRef = refImported mainModule (Name "f")
        -- λd. {m: λx. d + x + 1 + … + 38, pad: d} — a dictionary
        -- constructor whose size is far over 'inlineSizeBudget', so only
        -- a directive can paste it. The field annotation goes on `m`.
        bigCtor fieldAnn =
          abstraction (paramNamed (Name "d")) $
            literalObject
              [
                ( m
                , setAnn fieldAnn . abstraction (paramNamed (Name "x")) $
                    addChain
                      ( primBinOp
                          PrimAdd
                          (refLocal (Name "d"))
                          (refLocal (Name "x"))
                      )
                      [1 .. 38]
                )
              , (pad, refLocal (Name "d"))
              ]

    test "sinks a projection into a let" do
      let obj =
            literalObject [(m, literalInt 2), (pad, refLocal (Name "x"))]
          bound = application g (literalInt 1)
      runIdentity (sinkProjectionIntoLet (objectProp (let1 (Name "x") bound obj) m))
        === Just (let1 (Name "x") bound (objectProp obj m))

    test "sinks a constructor field read into a let" do
      -- The ctor-read twin of the projection sink: a directive-driven
      -- paste leaves the same let residue under a field read, which must
      -- sink for the case-of-known-constructor fold to reach the ctor.
      let ctorApp =
            application
              (ctor SumType extern (TyName "T") (CtorName "K") [FieldName "value0"])
              (refLocal (Name "x"))
          bound = application g (literalInt 1)
      runIdentity
        ( sinkProjectionIntoLet
            (dataArgumentByIndex SumType 0 (let1 (Name "x") bound ctorApp))
        )
        === Just (let1 (Name "x") bound (dataArgumentByIndex SumType 0 ctorApp))

    it ".label never keeps the method behind the dictionary" do
      -- Without the veto the small method resolves at both sites and
      -- the dictionary is collected.
      let dictDef =
            literalObject
              [
                ( m
                , setAnn (Just Never) . abstraction (paramNamed (Name "x")) $
                    application g (refLocal (Name "x"))
                )
              ]
          site x = application (objectProp dictRef m) (literalInt x)
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (dictName, dictDef)]
            , uberModuleExports =
                [(Name "main1", site 1), (Name "main2", site 2)]
            }
      namesOf optimized `shouldBe` ["dict"]
      Linker.uberModuleExports optimized
        `shouldBe` [(Name "main1", site 1), (Name "main2", site 2)]

    it ".label always resolves an over-budget method" do
      let dictDef =
            literalObject
              [
                ( m
                , setAnn (Just Always) . abstraction (paramNamed (Name "x")) $
                    addChain (refLocal (Name "x")) [1 .. 40]
                )
              ]
          site x = application (objectProp dictRef m) (literalInt x)
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (dictName, dictDef)]
            , uberModuleExports =
                [(Name "main1", site 0), (Name "main2", site 100)]
            }
      namesOf optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "main1", literalInt 820)
                   , (Name "main2", literalInt 920)
                   ]

    it ".label arity=1 resolves only applied projections" do
      let dictDef =
            literalObject
              [
                ( m
                , setAnn (Just (Arity 1))
                    . abstraction (paramNamed (Name "x"))
                    $ application g (refLocal (Name "x"))
                )
              ]
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (dictName, dictDef)]
            , uberModuleExports =
                [ (Name "main1", application (objectProp dictRef m) (literalInt 7))
                , (Name "main2", objectProp dictRef m)
                ]
            }
      namesOf optimized `shouldBe` ["dict"]
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "main1", application g (literalInt 7))
                   , (Name "main2", objectProp dictRef m)
                   ]

    it "...label always resolves a field after application" do
      let siteM =
            application
              (objectProp (application fRef (literalInt 3)) m)
              (literalInt 4)
          sitePad = objectProp (application fRef (literalInt 5)) pad
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (fName, bigCtor (Just Always))]
            , uberModuleExports =
                [(Name "main1", siteM), (Name "main2", sitePad)]
            }
      namesOf optimized `shouldBe` ["f"]
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "main1", literalInt 748)
                   , (Name "main2", sitePad)
                   ]

    it "...label arity=1 resolves only applied projections" do
      let siteApplied =
            application
              (objectProp (application fRef (literalInt 3)) m)
              (literalInt 4)
          siteBare = objectProp (application fRef (literalInt 3)) m
      optimized ←
        checked
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings =
                [Standalone (fName, bigCtor (Just (Arity 1)))]
            , uberModuleExports =
                [(Name "main1", siteApplied), (Name "main2", siteBare)]
            }
      namesOf optimized `shouldBe` ["f"]
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "main1", literalInt 748)
                   , (Name "main2", siteBare)
                   ]

  describe "folds constructor reads through a reference (issue #232)" do
    it "folds a field read over an applied constructor reference" do
      -- A user-written `Op f` compiles to a reference to the Op worker;
      -- a multi-use worker stays a binding, so the field read must fold
      -- through the reference or the cascade stalls at reading Op(f).
      let mainModule = moduleNameFromString "Main"
          extern = moduleNameFromString "Extern"
          g = refImported extern (Name "g")
          opName = QName mainModule (Name "Op")
          opDef =
            ctor
              ProductType
              mainModule
              (TyName "Op")
              (CtorName "Op")
              [FieldName "value0"]
          opRef = refImported mainModule (Name "Op")
          wrap n =
            abstraction (paramNamed (Name "x")) $
              application (application g (literalInt n)) (refLocal (Name "x"))
          site n x =
            application
              (dataArgumentByIndex ProductType 0 (application opRef (wrap n)))
              (literalInt x)
      optimized ←
        either (fail . show) pure . optimizedUberModuleChecked $
          Linker.UberModule
            { uberModuleForeigns = []
            , uberModuleBindings = [Standalone (opName, opDef)]
            , uberModuleExports =
                [(Name "main1", site 1 7), (Name "main2", site 2 9)]
            }
      Linker.uberModuleBindings optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [
                     ( Name "main1"
                     , application (application g (literalInt 1)) (literalInt 7)
                     )
                   ,
                     ( Name "main2"
                     , application (application g (literalInt 2)) (literalInt 9)
                     )
                   ]

  describe "keeps foreign module tables hoisted (issue #175)" do
    -- A foreign module's value table must stay a single shared binding:
    -- its export values (some of which are Lua table constructors with
    -- identity, e.g. `unit = {}`) are invisible to the IR, so pasting the
    -- 'ForeignImport' into its use site can multiply allocations and
    -- change identity. Here the only use sits under a lambda: inlining
    -- would re-create the table on every call.
    test "does not inline a used-once foreign import" do
      let mainModule = moduleNameFromString "Main"
          original =
            Module
              { moduleName = mainModule
              , moduleBindings =
                  [ Standalone
                      ( noAnn
                      , Name "f"
                      , abstraction paramUnused (refLocal (Name "x"))
                      )
                  ]
              , moduleImports = []
              , moduleExports = [Name "f"]
              , moduleReExports = Map.empty
              , moduleForeigns = [(noAnn, Name "x")]
              , modulePath = "Main.purs"
              }
          optimized =
            optimizedUberModule $
              Linker.makeUberModule (LinkAsModule mainModule) [original]
          foreignKept =
            [ qn
            | Standalone (qn, ForeignImport {}) ←
                Linker.uberModuleBindings optimized
            ]
      annotateShow optimized
      foreignKept === [QName mainModule (Name "foreign")]

  describe "respects @inline never on foreign export names (issue #175)" do
    -- The pragma annotation drained into 'moduleForeigns' must reach the
    -- accessor the Linker binds the name to, overriding the default
    -- 'Always'; the veto then keeps the accessor as a shared binding
    -- (a fork's way to declare sharing intent for an FFI value).
    test "keeps a never-annotated foreign accessor instead of inlining it" do
      let mainModule = moduleNameFromString "Main"
          original =
            Module
              { moduleName = mainModule
              , moduleBindings =
                  [Standalone (noAnn, Name "use", refLocal (Name "x"))]
              , moduleImports = []
              , moduleExports = [Name "use"]
              , moduleReExports = Map.empty
              , moduleForeigns = [(Just Never, Name "x")]
              , modulePath = "Main.purs"
              }
          optimized =
            optimizedUberModule $
              Linker.makeUberModule (LinkAsModule mainModule) [original]
          accessorKept =
            [ (qn, getAnn expr)
            | Standalone (qn, expr) ← Linker.uberModuleBindings optimized
            , qn == QName mainModule (Name "x")
            ]
      annotateShow optimized
      accessorKept === [(QName mainModule (Name "x"), Just Never)]

  describe "shares multi-use foreign accessors (issue #248)" do
    -- With stage-2 promotion a kept accessor binding becomes a chunk
    -- local, so at two or more use sites the shared form beats a field
    -- read repeated per site. An unannotated accessor therefore
    -- dissolves only into a single use site; @inline always@ restores
    -- per-site dissolution at any use count.
    let mainModule = moduleNameFromString "Main"
        moduleWith ∷ [Grouping (Ann, Name, Exp)] → [Name] → Ann → Module
        moduleWith bindings exports foreignAnn =
          Module
            { moduleName = mainModule
            , moduleBindings = bindings
            , moduleImports = []
            , moduleExports = exports
            , moduleReExports = Map.empty
            , moduleForeigns = [(foreignAnn, Name "x")]
            , modulePath = "Main.purs"
            }
        checked =
          either (fail . show) pure
            . optimizedUberModuleChecked
            . Linker.makeUberModule (LinkAsModule mainModule)
            . pure
        accessorBindings ∷ Linker.UberModule → [QName]
        accessorBindings optimized =
          [ qn
          | Standalone (qn, ObjectProp {}) ←
              Linker.uberModuleBindings optimized
          ]
        xAccessor ∷ Ann → Exp
        xAccessor ann =
          setAnn ann $
            objectProp
              (refImported mainModule (Name "foreign"))
              (PropName "x")

    it "keeps an unannotated accessor referenced twice" do
      optimized ←
        checked $
          moduleWith
            [ Standalone (noAnn, Name "a", refLocal (Name "x"))
            , Standalone (noAnn, Name "b", refLocal (Name "x"))
            ]
            [Name "a", Name "b"]
            noAnn
      accessorBindings optimized `shouldBe` [QName mainModule (Name "x")]
      -- Both use sites reference the shared binding instead of
      -- re-reading the field off the foreign table.
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "a", refImported mainModule (Name "x"))
                   , (Name "b", refImported mainModule (Name "x"))
                   ]

    it "dissolves an unannotated accessor used once" do
      optimized ←
        checked $
          moduleWith
            [Standalone (noAnn, Name "a", refLocal (Name "x"))]
            [Name "a"]
            noAnn
      accessorBindings optimized `shouldBe` []
      Linker.uberModuleExports optimized
        `shouldBe` [(Name "a", xAccessor noAnn)]

    it "dissolves a twice-referenced accessor annotated @inline always" do
      optimized ←
        checked $
          moduleWith
            [ Standalone (noAnn, Name "a", refLocal (Name "x"))
            , Standalone (noAnn, Name "b", refLocal (Name "x"))
            ]
            [Name "a", Name "b"]
            (Just Always)
      accessorBindings optimized `shouldBe` []
      -- The pasted reads shed the annotation at the paste; the per-site
      -- contract holds anyway, because 'shareForeignAccessors' consults
      -- the directive by name, not by reading the (unreliable) node
      -- annotations.
      Linker.uberModuleExports optimized
        `shouldBe` [ (Name "a", xAccessor noAnn)
                   , (Name "b", xAccessor noAnn)
                   ]

    it "re-binds annotated reads of an undirected name" do
      -- A fold can transplant a stray annotation onto a read
      -- ('reduceObjectProp' hands the projection's own annotation to the
      -- folded value), so the pass consults no node annotations: the
      -- directive lives in the name-keyed policy alone. The inserted
      -- binding is normalized to no annotation, whichever copy became
      -- the representative.
      let foreignBinding =
            Standalone
              ( QName mainModule (Name "foreign")
              , ForeignImport noAnn mainModule "Main.purs" [(noAnn, Name "x")]
              )
          shared =
            shareForeignAccessors
              mempty
              Linker.UberModule
                { uberModuleForeigns = []
                , uberModuleBindings = [foreignBinding]
                , uberModuleExports =
                    [ (Name "a", xAccessor (Just Never))
                    , (Name "b", xAccessor (Just Never))
                    ]
                }
      Linker.uberModuleExports shared
        `shouldBe` [ (Name "a", refImported mainModule (Name "x"))
                   , (Name "b", refImported mainModule (Name "x"))
                   ]
      let insertedAnns =
            [ getAnn rhs
            | Standalone (qn, rhs) ← Linker.uberModuleBindings shared
            , qn == QName mainModule (Name "x")
            ]
      insertedAnns `shouldBe` [Nothing]

  describe "counts free references against the live module (#143)" do
    -- Within a single 'optimizeModule' run the use-once check must consult
    -- the current (post-substitution) view of the module, not a stale
    -- snapshot of the original bindings. Here `y` collapses to a bare
    -- reference to `x` and is inlined into the export, leaving `x`
    -- referenced exactly once; counting against the live view inlines `x`
    -- too, whereas counting the two pre-collapse occurrences in the
    -- original `y` wrongly keeps it. A single run is deliberate: the
    -- optimize+dce fixpoint masks the misjudgment by self-correcting on a
    -- later iteration (issue #143).
    it "inlines a binding that becomes used-once mid-run" do
      let main' = moduleNameFromString "Main"
          extern = moduleNameFromString "Extern"
          -- Non-inlinable and never rewritten by 'optimizeExp'.
          xExpr = application (refImported extern (Name "f")) (literalInt 1)
          yExpr =
            ifThenElse
              (literalBool True)
              (refImported main' (Name "x"))
              (refImported main' (Name "x"))
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [ Standalone (QName main' (Name "x"), xExpr)
                  , Standalone (QName main' (Name "y"), yExpr)
                  ]
              , uberModuleExports =
                  [(Name "main", refImported main' (Name "y"))]
              }
          optimized = fst (runSupply (optimizeModule SkipCallSites mempty original))
      Linker.uberModuleBindings optimized `shouldBe` []
      Linker.uberModuleExports optimized `shouldBe` [(Name "main", xExpr)]

  describe "inliner unlocks more optimizations" do
    test "constant folding after inlining" do
      name ← forAll Gen.name
      let uberName = moduleNameFromString "Main"
          linkMode = LinkAsModule uberName
          mkUber = Linker.makeUberModule linkMode . pure . wrapInModule
      let original =
            mkUber $
              let1 name (literalInt 42) $
                ifThenElse
                  (eq (refLocal name) (literalInt 42))
                  (literalInt 1)
                  (literalInt 2)
          expected =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "main", literalInt 1)]
              }
      annotateShow original
      annotateShow expected
      optimizedUberModule original === expected

    -- The live trigger for the projection fold: inlining a record
    -- literal into its projection site creates the redex mid-fixpoint,
    -- and DCE then drops the emptied binding.
    test "record projection after inlining" do
      name ← forAll Gen.name
      let uberName = moduleNameFromString "Main"
          linkMode = LinkAsModule uberName
          mkUber = Linker.makeUberModule linkMode . pure . wrapInModule
          original =
            mkUber $
              let1
                name
                ( literalObject
                    [ (PropName "foo", literalInt 1)
                    , (PropName "bar", literalInt 2)
                    ]
                )
                (objectProp (refLocal name) (PropName "foo"))
          expected =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "main", literalInt 1)]
              }
      annotateShow original
      optimizedUberModule original === expected

    -- The constructor twin of the record-projection test above (#177):
    -- inlining a saturated constructor into its field read forms the
    -- redex mid-fixpoint, the fold takes the argument, and DCE drops the
    -- emptied binding.
    test "constructor field read after inlining" do
      name ← forAll Gen.name
      let uberName = moduleNameFromString "Main"
          linkMode = LinkAsModule uberName
          mkUber = Linker.makeUberModule linkMode . pure . wrapInModule
          boxCtor =
            ctor
              ProductType
              uberName
              (TyName "Box")
              (CtorName "Box")
              [FieldName "value0"]
          original =
            mkUber $
              let1
                name
                (application boxCtor (literalInt 1))
                (dataArgumentByIndex ProductType 0 (refLocal name))
          expected =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "main", literalInt 1)]
              }
      annotateShow original
      optimizedUberModule original === expected

    -- The tag twin: a single-use scrutinee lets inlining bring the
    -- constructor to the tag read, which folds to the tag string and
    -- collapses the surrounding equality — the payoff cascade end to end.
    test "constructor tag read after inlining" do
      name ← forAll Gen.name
      let uberName = moduleNameFromString "Main"
          linkMode = LinkAsModule uberName
          mkUber = Linker.makeUberModule linkMode . pure . wrapInModule
          maybeTy = TyName "Maybe"
          justName = CtorName "Just"
          justCtor =
            ctor SumType uberName maybeTy justName [FieldName "value0"]
          tag = ctorId uberName maybeTy justName
          original =
            mkUber $
              let1
                name
                (application justCtor (literalInt 1))
                (eq (reflectCtor (refLocal name)) (literalString tag))
          expected =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "main", literalBool True)]
              }
      annotateShow original
      optimizedUberModule original === expected

  describe "scoping invariants" do
    -- Mimics issue #37: an inlined binding contains a let with a
    -- reference bound by an earlier sibling; inlining it under a binder
    -- with the same name must not leave the reference unbound.
    -- See Note [Sequential scoping of Let bindings]
    test "inlining bindings does not unbind let-bound references" do
      let mainModule = moduleNameFromString "Main"
          dict = moduleNameFromString "Dict"
          fooExp =
            abstraction (paramNamed (Name "fn1")) $
              lets
                ( Standalone
                    ( noAnn
                    , Name "Bind1"
                    , application
                        (refImported dict (Name "bind"))
                        (refLocal (Name "fn1"))
                    )
                    :| [ Standalone
                           ( noAnn
                           , Name "discard1"
                           , application
                               (refImported dict (Name "discard"))
                               (refLocal (Name "Bind1"))
                           )
                       ]
                )
                ( application
                    (refLocal (Name "discard1"))
                    (refLocal (Name "discard1"))
                )
          barExp =
            abstraction (paramNamed (Name "f")) $
              lets
                ( Standalone
                    ( noAnn
                    , Name "Bind1"
                    , application
                        (refImported dict (Name "bind"))
                        (refLocal (Name "f"))
                    )
                    :| []
                )
                ( application
                    ( application
                        (refImported mainModule (Name "foo"))
                        (refLocal (Name "f"))
                    )
                    ( application
                        (refLocal (Name "Bind1"))
                        (refLocal (Name "Bind1"))
                    )
                )
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings =
                  [ Standalone (QName mainModule (Name "foo"), fooExp)
                  , Standalone (QName mainModule (Name "bar"), barExp)
                  ]
              , uberModuleExports =
                  [
                    ( Name "baz"
                    , application
                        (refImported mainModule (Name "bar"))
                        (literalInt 7)
                    )
                  ]
              }
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []

    -- Issue #56: `b` is bound by an outer λ while the reduced inner λ is
    -- \*also* named `b`; reducing the redexes must leave the surviving
    -- reference bound to the outer binder. This is the IR shape
    -- `Data.Array.foldRecM` boils down to.
    test "beta reduction does not unbind a reference shadowed by the binder" do
      let a = Name "a"
          b = Name "b"
          inner =
            abstraction (paramNamed a) $
              abstraction (paramNamed b) $
                literalObject
                  [ (PropName "p", refLocal a)
                  , (PropName "q", refLocal b)
                  ]
          -- (\b -> (\a -> \b -> { p: a, q: b }) b 0)
          shadowed =
            abstraction (paramNamed b) $
              application
                (application inner (refLocal b))
                (literalInt 0)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "foldRecMShape", shadowed)]
              }
          -- After the redexes are reduced only the outer λ remains, so the
          -- surviving reference is the outer `b`.
          expected =
            abstraction (paramNamed b) $
              literalObject
                [ (PropName "p", refLocal b)
                , (PropName "q", literalInt 0)
                ]
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []
      Linker.uberModuleExports optimized === [(Name "foldRecMShape", expected)]

    -- Sibling of #56 in the DCE pass (found by the property below).
    -- Dead-code elimination blanks the unused inner λj to ParamUnused;
    -- every reference to the outer j must stay bound to it.
    test "blanking an unused shadowing binder keeps outer references bound" do
      let j = Name "j"
          k = Name "k"
          -- \j -> (\k -> { foo: (\_ -> \j -> k) 0 }) j
          shadowed =
            abstraction (paramNamed j) $
              application
                ( abstraction (paramNamed k) $
                    literalObject
                      [
                        ( PropName "foo"
                        , application
                            ( abstraction paramUnused $
                                abstraction (paramNamed j) (refLocal k)
                            )
                            (literalInt 0)
                        )
                      ]
                )
                (refLocal j)
          original =
            Linker.UberModule
              { uberModuleForeigns = []
              , uberModuleBindings = []
              , uberModuleExports = [(Name "shape", shadowed)]
              }
          optimized = optimizedUberModule original
          offending =
            foldMap (unboundLocals . snd) (Linker.uberModuleExports optimized)
      annotateShow optimized
      offending === []

    -- The general invariant behind #37 and #56: optimizing a well-scoped
    -- expression must never produce an unbound local reference. Runs through the
    -- whole 'optimizedUberModule' pipeline (not a single 'optimizedExpression'
    -- pass) because the #56 dangling reference only surfaces once an enclosing
    -- redex is reduced on a later iteration.
    prop "optimization keeps expressions well-scoped" do
      e ← forAll Gen.scopedExp
      annotateShow e
      unboundLocals e === [] -- the generator only emits well-scoped terms
      let optimized =
            optimizedUberModule
              Linker.UberModule
                { Linker.uberModuleForeigns = []
                , Linker.uberModuleBindings = []
                , Linker.uberModuleExports = [(Name "root", e)]
                }
      lintWellScoped optimized === []
      -- The full pipeline ends GUC-clean, not merely well-scoped:
      lintUniqueBinders optimized === []

    -- Soundness of a single bottom-up 'optimizedExpression' pass over
    -- generated input — which, since the shared generator emits
    -- 'ReflectCtor' / 'DataArgumentByIndex' over saturated constructor
    -- applications, actually fires the #177 case-of-known-constructor fold.
    prop "optimizedExpression stays sound over generated expressions" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      let once = optimizedExpression e
      -- Never introduces a free reference; may drop them (the #177 fold,
      -- DCE, beta, and unreachable-branch removal all shrink the ref set),
      -- so this is a subset check, not FloatIn's equality.
      Map.isSubmapOfBy (<=) (countFreeRefs once) (countFreeRefs e) === True
      -- Stays well-scoped.
      unboundLocals once === []

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

wrapInModule ∷ Exp → Module
wrapInModule e =
  Module
    { moduleName = moduleNameFromString "Main"
    , moduleBindings = [Standalone (noAnn, Name "main", e)]
    , moduleImports = []
    , moduleExports = [Name "main"]
    , moduleReExports = Map.empty
    , moduleForeigns = []
    , modulePath = "Main.purs"
    }

let1 ∷ Name → Exp → Exp → Exp
let1 n e = lets (Standalone (noAnn, n, e) :| [])

isRef ∷ Exp → Bool
isRef = \case
  Ref {} → True
  _ → False
