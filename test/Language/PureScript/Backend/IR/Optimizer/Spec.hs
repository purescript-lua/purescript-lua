module Language.PureScript.Backend.IR.Optimizer.Spec where

import Data.Map qualified as Map
import Data.Text qualified as Text
import Hedgehog (PropertyT, annotateShow, diff, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Inliner (Annotation (Always, Never))
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
  , Qualified (Local)
  , TyName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Optimizer
  ( optimizeModule
  , optimizedExpression
  , optimizedUberModule
  , optimizedUberModuleChecked
  )
import Language.PureScript.Backend.IR.Supply (runSupply)
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (ProductType, SumType)
  , Exp
  , Grouping (..)
  , Module (..)
  , RawExp (..)
  , abstraction
  , abstractionN
  , alphaEq
  , application
  , applicationN
  , countFreeRef
  , ctor
  , ctorId
  , dataArgumentByIndex
  , eq
  , getAnn
  , ifThenElse
  , isLiteral
  , lets
  , literalBool
  , literalInt
  , literalObject
  , literalString
  , noAnn
  , objectProp
  , objectUpdate
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , reflectCtor
  , setAnn
  )
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
    -- duplicated into every use site and dropped from the bindings.
    test "keeps a binding whose RHS folds to an annotated field" do
      let mainModule = moduleNameFromString "Main"
          addExp = objectProp (literalObject [(foo, accessor)]) foo
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
      optimizedExpression (dataArgumentByIndex 0 (just (literalInt 7)))
        `shouldBe` literalInt 7

    it "reads the second field of a saturated product application" do
      optimizedExpression
        (dataArgumentByIndex 1 (tuple (literalInt 1) (literalInt 2)))
        `shouldBe` literalInt 2

    it "collapses a tag-equality test into its result" do
      -- The payoff cascade: the folded tag meets the surrounding Eq and
      -- constant folding reduces the whole decision-tree test.
      let original = eq (reflectCtor (just (literalInt 1))) (literalString justTag)
      optimizedExpression original `shouldBe` literalBool True

    it "declines a partially applied constructor" do
      -- One argument against a two-field constructor: still a function,
      -- so the field read must not fire.
      let original = dataArgumentByIndex 0 (application tupleCtor (literalInt 1))
      optimizedExpression original `shouldBe` original

    it "declines a product-type tag read" do
      -- Product constructors carry no $ctor row at runtime, so folding
      -- the tag would invent a value the runtime reads as nil.
      let original = reflectCtor (tuple (literalInt 1) (literalInt 2))
      optimizedExpression original `shouldBe` original

    it "drops the discarded arguments of a field read" do
      -- Only the read field survives; the sibling is gone, not Let-bound.
      optimizedExpression
        (dataArgumentByIndex 0 (tuple (refLocal (Name "a")) (refLocal (Name "b"))))
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
      let original = dataArgumentByIndex 0 (just accessor)
      getAnn (optimizedExpression original) `shouldBe` Nothing

    it "keeps the read node's own annotation on the folded field" do
      let original = DataArgumentByIndex (Just Never) 0 (just accessor)
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
      optimizedExpression (dataArgumentByIndex index app) === kept

    prop "folds a saturated sum-type tag read to the tag string" do
      args ← forAll (Gen.list (Range.linear 0 5) trivialArg)
      modName ← forAll Gen.moduleName
      ty ← forAll Gen.tyName
      cn ← forAll Gen.ctorName
      let fields = FieldName . show <$> [1 .. length args]
          app = foldl' application (ctor SumType modName ty cn fields) args
      optimizedExpression (reflectCtor app) === literalString (ctorId modName ty cn)

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
          optimized = fst (runSupply (optimizeModule mempty original))
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
                (dataArgumentByIndex 0 (refLocal name))
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
