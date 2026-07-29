module Language.PureScript.Backend.IR.CSE.Spec where

import Data.Map qualified as Map
import Data.Set qualified as Set
import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.CSE (eliminateCommonSubexpressions)
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter (lintUniqueBinders, lintWellScoped)
import Language.PureScript.Backend.IR.Names
  ( CtorName (CtorName)
  , ModuleName
  , Name (Name)
  , PropName (PropName)
  , QName (QName)
  , TyName (TyName)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.SpecUtils
  ( applyPassToExpression
  , emptyUberModule
  )
import Language.PureScript.Backend.IR.Supply (runSupply)
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (SumType)
  , Ann
  , Exp
  , Grouping (..)
  , abstraction
  , application
  , countFreeRefs
  , ctor
  , dataArgumentByIndex
  , exception
  , freshenBinders
  , ifThenElse
  , lets
  , literalArray
  , literalInt
  , literalObject
  , noAnn
  , objectProp
  , paramNamed
  , refImported
  , refLocal
  , reflectCtor
  )
import Language.PureScript.Backend.IR.Uniquify (uniquifyNamesInExpr)
import Test.Hspec (Spec, describe, it, shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)

spec ∷ Spec
spec = describe "CSE" do
  let f = refLocal (Name "f")
      g = refLocal (Name "g")
      r = refLocal (Name "r")
      v = Name "v"
      cond = refLocal (Name "cond")
      cse0 = refLocal (Name "$cse0")
      cse1 = refLocal (Name "$cse1")
      -- λname. name — copies with distinct binders: alpha-equivalent
      -- without being equal.
      lam ∷ Text → Exp
      lam name = abstraction (paramNamed (Name name)) (refLocal (Name name))
      bind0, bind1 ∷ Exp → Grouping (Ann, Name, Exp)
      bind0 rhs = Standalone (noAnn, Name "$cse0", rhs)
      bind1 rhs = Standalone (noAnn, Name "$cse1", rhs)
      prj ∷ Exp → Exp
      prj base = objectProp base (PropName "run")

  it "hoists two alpha-equivalent lambdas into one shared binding" do
    let expr = application (application f (lam "a")) (lam "b")
        expected =
          lets
            (pure (bind0 (lam "a")))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "hoists Lets whose Standalone RHS references an outer binder (#349)" do
    -- See Note [Sequential scoping of Let bindings]: a Standalone binding
    -- is non-recursive, so the right-hand-side x is a free occurrence of
    -- the enclosing x in both copies below — which therefore differ only
    -- in the name chosen for the binder. Wrapping in a lambda makes each
    -- copy a candidate.
    let shadowing name =
          abstraction (paramNamed (Name "$p")) $
            lets
              (pure (Standalone (noAnn, Name name, refLocal (Name "x"))))
              (refLocal (Name name))
        expr = application (application f (shadowing "x")) (shadowing "y")
        expected =
          lets
            (pure (bind0 (shadowing "x")))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "hoists recursive groups differing only in the member name" do
    -- The contrast to the case above: a RecursiveGroup member's
    -- right-hand side does see its own binder, so the self-reference is
    -- bound in both copies and the two are alpha-equivalent.
    let recursive name =
          let self = Name name
           in abstraction (paramNamed (Name "$p")) $
                lets
                  (pure (RecursiveGroup ((noAnn, self, refLocal self) :| [])))
                  (refLocal self)
        expr = application (application g (recursive "a")) (recursive "b")
        expected =
          lets
            (pure (bind0 (recursive "a")))
            (application (application g cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "hoists a repeat sitting in both branches of an if" do
    let expr =
          ifThenElse cond (application f (lam "a")) (application g (lam "b"))
        expected =
          lets
            (pure (bind0 (lam "a")))
            (ifThenElse cond (application f cse0) (application g cse0))
    cseExpression expr `shouldBe` expected

  it "does not hoist a single occurrence" do
    let expr = application f (lam "a")
    cseExpression expr `shouldBe` expr

  it "does not group occurrences across a lambda boundary" do
    -- One copy per inner lambda body; the inner lambdas themselves are
    -- not alpha-equivalent (different heads applied), so nothing repeats
    -- within any one block.
    let expr =
          application
            ( application
                f
                (abstraction (paramNamed (Name "p")) (application f (lam "a")))
            )
            (abstraction (paramNamed (Name "q")) (application g (lam "b")))
    cseExpression expr `shouldBe` expr

  it "hoists a repeated projection out of a reference" do
    let expr = application (prj r) (application (prj r) (refLocal (Name "x")))
        expected =
          lets
            (pure (bind0 (prj r)))
            (application cse0 (application cse0 (refLocal (Name "x"))))
    cseExpression expr `shouldBe` expected

  it "hoists a repeated projection chain whole" do
    -- r.run.run twice: the outer chain is hoisted; the inner r.run
    -- repeat then survives only inside the shared right-hand side, so it
    -- is not hoisted separately.
    let chain = prj (prj r)
        expr = application (application f chain) chain
        expected =
          lets
            (pure (bind0 chain))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "hoists a repeated tag read" do
    let tagRead = reflectCtor r
        expr = application (application f tagRead) tagRead
        expected =
          lets
            (pure (bind0 tagRead))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "does not hoist a read through a sum-variant slot" do
    -- The matcher emits this chain only under the tag guard that
    -- establishes the variant: the slot read yields nil for any other
    -- variant, and the tag read through it would throw. Only the inner
    -- slot read — a never-throwing read over the scrutinee itself — is
    -- shared; the read through it stays at its guarded sites.
    let slotRead = dataArgumentByIndex SumType 0 r
        chain = reflectCtor slotRead
        expr = ifThenElse cond (application f chain) (application g chain)
        expected =
          lets
            (pure (bind0 slotRead))
            ( ifThenElse
                cond
                (application f (reflectCtor cse0))
                (application g (reflectCtor cse0))
            )
    cseExpression expr `shouldBe` expected

  it "keeps an `inline always` accessor read pasted per site" do
    -- The deference share-accessors pays (issue #248): an explicit
    -- always directive pins the foreign-accessor read to its use sites.
    let m1 = moduleNameFromString "M1"
        readAcc =
          objectProp (refImported m1 (Name "foreign")) (PropName "inc")
        expr = application (application f readAcc) readAcc
        vetoed =
          runSupply $
            eliminateCommonSubexpressions
              (Set.singleton (QName m1 (Name "inc")))
              emptyUberModule {uberModuleExports = [(Name "main", expr)]}
    uberModuleExports vetoed `shouldBe` [(Name "main", expr)]
    -- Without the directive the same read is shared:
    cseExpression expr
      `shouldBe` lets
        (pure (bind0 readAcc))
        (application (application f cse0) cse0)

  it "does not hoist a candidate referencing a block-bound Let binder" do
    -- v is bound within the block, below the hoist point.
    let expr =
          lets
            (pure (Standalone (noAnn, v, application f r)))
            (application (application f (prj (refLocal v))) (prj (refLocal v)))
    cseExpression expr `shouldBe` expr

  it "does not hoist arbitrary applications" do
    let expr = application (application g (application f r)) (application f r)
    cseExpression expr `shouldBe` expr

  it "does not hoist exceptions" do
    let expr = application (application f (exception "boom")) (exception "boom")
    cseExpression expr `shouldBe` expr

  it "hoists a saturated constructor application of effect-free values" do
    let justR = ctor SumType mn (TyName "Maybe") (CtorName "Just") [r]
        expr = application (application f justR) justR
        expected =
          lets
            (pure (bind0 justR))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "does not hoist an unsaturated constructor application" do
    -- A partial application is a call of the curried wrapper — a
    -- reference-headed spine (an unsaturated 'Ctor' node is
    -- unrepresentable), which CSE declines like any other call.
    let partial = application (refImported mn (Name "Pair")) r
        expr = application (application f partial) partial
    cseExpression expr `shouldBe` expr

  it "does not hoist a constructor application of effectful arguments" do
    let justCall =
          ctor SumType mn (TyName "Maybe") (CtorName "Just") [application f r]
        expr = application (application f justCall) justCall
    cseExpression expr `shouldBe` expr

  it "hoists a repeated pure array literal" do
    let arr = literalArray [literalInt 1, literalInt 2]
        expr = application (application f arr) arr
        expected =
          lets
            (pure (bind0 arr))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "does not hoist an empty array literal" do
    let arr = literalArray []
        expr = application (application f arr) arr
    cseExpression expr `shouldBe` expr

  it "recounts nested repeats against the shared copy" do
    -- The object repeats and is hoisted; the lambda inside it then
    -- occurs only once (in the shared right-hand side), so no second
    -- binding is minted.
    let obj name = literalObject [(PropName "run", lam name)]
        expr = application (application f (obj "a")) (obj "b")
        expected =
          lets
            (pure (bind0 (obj "a")))
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "hoists sibling repeats inside a single container" do
    let obj =
          literalObject
            [(PropName "one", lam "a"), (PropName "two", lam "b")]
        expr = application f obj
        expected =
          lets
            (pure (bind0 (lam "a")))
            ( application
                f
                (literalObject [(PropName "one", cse0), (PropName "two", cse0)])
            )
    cseExpression expr `shouldBe` expected

  it
    "hoists largest-first, wrapping the smaller group's binding outside \
    \so the bigger right-hand side can reference it"
    do
      let obj name = literalObject [(PropName "run", lam name)]
          expr =
            application
              (application (application g (obj "a")) (obj "b"))
              (lam "c")
          expected =
            lets
              (pure (bind1 (lam "a")))
              ( lets
                  (pure (bind0 (literalObject [(PropName "run", cse1)])))
                  (application (application (application g cse0) cse0) cse1)
              )
      cseExpression expr `shouldBe` expected

  it "processes the bodies of hoisted lambdas as their own blocks" do
    -- The repeated outer lambda is shared; within its single surviving
    -- body the projection repeat is then shared as well.
    let body = application (prj r) (application (prj r) (refLocal (Name "p")))
        outer name = abstraction (paramNamed (Name name)) body
        expr = application (application f (outer "p1")) (outer "p2")
        expected =
          lets
            ( pure
                ( bind0
                    ( abstraction
                        (paramNamed (Name "p1"))
                        ( lets
                            (pure (bind1 (prj r)))
                            ( application
                                cse1
                                (application cse1 (refLocal (Name "p")))
                            )
                        )
                    )
                )
            )
            (application (application f cse0) cse0)
    cseExpression expr `shouldBe` expected

  it "stops hoisting when the block is at the Lua locals budget" do
    -- Each hoist costs the enclosing Lua function a local slot; a block
    -- already binding 160 gets no further sharing (one under, it does).
    let manyLets ∷ Int → Exp → Exp
        manyLets n body =
          foldr
            ( \i acc →
                lets
                  (pure (Standalone (noAnn, Name ("v" <> show i), literalInt 1)))
                  acc
            )
            body
            [1 .. n]
        shared = application (application f (lam "a")) (lam "b")
    cseExpression (manyLets 160 shared) `shouldBe` manyLets 160 shared
    cseExpression (manyLets 159 shared)
      `shouldBe` lets
        (pure (bind0 (lam "a")))
        (manyLets 159 (application (application f cse0) cse0))

  it "rewrites uberModuleBindings, not only exports" do
    let expr = application (application f (lam "a")) (lam "b")
        expected =
          lets
            (pure (bind0 (lam "a")))
            (application (application f cse0) cse0)
        qname = QName mn (Name "top")
        uber =
          cseModule
            emptyUberModule {uberModuleBindings = [Standalone (qname, expr)]}
    uberModuleBindings uber `shouldBe` [Standalone (qname, expected)]

  describe "properties (generated expressions)" do
    prop 200 "preserves the GUC invariants" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      let optimized =
            cseModule emptyUberModule {uberModuleExports = [(Name "main", e)]}
      lintWellScoped optimized === []
      lintUniqueBinders optimized === []

    prop 200 "is idempotent" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      let once = cseExpression e
      cseExpression once === once

    prop 200 "preserves the set of free references" do
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      Map.keysSet (countFreeRefs (cseExpression e))
        === Map.keysSet (countFreeRefs e)

    prop 200 "keys alpha-equivalent expressions equally" do
      -- Renaming every binder must not change the canonical form the
      -- pass groups by: the pass relies on this to recognise freshened
      -- pastes of one expression as one group. Wrapping in a lambda
      -- makes the pair an unconditional candidate; the identical-copies
      -- expression on the right is the reference result.
      e ← forAll (uniquifyNamesInExpr <$> Gen.scopedExp)
      let renamed = runSupply (freshenBinders e)
          wrap = abstraction (paramNamed (Name "$p"))
          f' = refLocal (Name "f")
          shared x y = application (application f' (wrap x)) (wrap y)
      cseExpression (shared e renamed) === cseExpression (shared e e)

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

mn ∷ ModuleName
mn = moduleNameFromString "Main"

cseModule ∷ UberModule → UberModule
cseModule = runSupply . eliminateCommonSubexpressions mempty

cseExpression ∷ HasCallStack ⇒ Exp → Exp
cseExpression = applyPassToExpression "cseExpression" cseModule
