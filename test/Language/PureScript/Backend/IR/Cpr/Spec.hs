module Language.PureScript.Backend.IR.Cpr.Spec where

import Data.List qualified as List
import Data.Set qualified as Set
import Hedgehog (Gen, annotateShow, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Cpr (cprWorkerWrapper)
import Language.PureScript.Backend.IR.Inliner qualified as Inline
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( Violation
  , lintUniqueBinders
  , lintWellApplied
  , lintWellScoped
  )
import Language.PureScript.Backend.IR.Names
  ( CtorName (..)
  , ModuleName
  , Name (..)
  , QName (..)
  , TyName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Supply (runSupply)
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (..)
  , Binding
  , Exp
  , Grouping (..)
  , RawExp (..)
  , WasRewritten (..)
  , abstraction
  , abstractionN
  , application
  , applicationN
  , ctor
  , dataArgumentByIndex
  , eq
  , exception
  , ifThenElse
  , letValues
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , refImported
  , refLocal
  , setAnn
  , values
  )
import Test.Hspec (Spec, describe, it, shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)

runCpr ∷ Set QName → UberModule → (UberModule, WasRewritten)
runCpr veto = runSupply . cprWorkerWrapper veto

spec ∷ Spec
spec = describe "IR CPR (result worker/wrapper)" do
  it "splits a ctor-tailed binding and rewrites the deconstructing site" do
    let m =
          moduleOf
            [Standalone (qn "f", def1)]
            [(Name "main", deconstructingSite f)]
    runCpr mempty m
      `shouldBe` ( moduleOf
                     [ Standalone (qn "f$r", worker1)
                     , Standalone (qn "f", wrapper1)
                     ]
                     [(Name "main", rewrittenSite ("$v0", "$v1"))]
                 , Rewritten
                 )

  it "splits an n-ary candidate — the post-uncurry worker story" do
    -- Computed fields: a bare @Pair a b@ would be the excluded
    -- constructor-function shape.
    let def2 =
          abstractionN
            (paramNamed (Name "a") :| [paramNamed (Name "b")])
            ( pairOf
                (eq (refLocal (Name "a")) (refLocal (Name "b")))
                (refLocal (Name "a"))
            )
        site =
          lets
            ( Standalone
                ( noAnn
                , Name "v"
                , applicationN f (literalInt 1 :| [literalInt 2])
                )
                :| []
            )
            (dataArgumentByIndex ProductType 1 (refLocal (Name "v")))
        m = moduleOf [Standalone (qn "f", def2)] [(Name "main", site)]
        (m', rewritten) = runCpr mempty m
    rewritten `shouldBe` Rewritten
    fmap fst (listGroupings m') `shouldBe` [qn "f$r", qn "f"]

  it "splits when both IfThenElse arms return the same constructor" do
    let branchy =
          abstraction (paramNamed s) $
            ifThenElse
              (eq (refLocal s) (literalInt 0))
              (pairOf (literalInt 1) (refLocal s))
              (pairOf (refLocal s) (literalInt 2))
        m =
          moduleOf
            [Standalone (qn "f", branchy)]
            [(Name "main", deconstructingSite f)]
        (m', rewritten) = runCpr mempty m
    rewritten `shouldBe` Rewritten
    fmap fst (listGroupings m') `shouldBe` [qn "f$r", qn "f"]

  it "admits an Exception tail — that path never returns" do
    let partial =
          abstraction (paramNamed s) $
            ifThenElse
              (eq (refLocal s) (literalInt 0))
              (exception "empty")
              (pairOf (refLocal s) (literalInt 2))
        m =
          moduleOf
            [Standalone (qn "f", partial)]
            [(Name "main", deconstructingSite f)]
    snd (runCpr mempty m) `shouldBe` Rewritten

  it "declines a non-constructor tail" do
    let def' = abstraction (paramNamed s) (eq (refLocal s) (literalInt 1))
        m =
          moduleOf
            [Standalone (qn "f", def')]
            [(Name "main", deconstructingSite f)]
    runCpr mempty m `shouldBe` (m, Unmodified)

  it "declines mixed constructors across branches" do
    let mixed =
          abstraction (paramNamed s) $
            ifThenElse
              (eq (refLocal s) (literalInt 0))
              (pairOf (literalInt 1) (refLocal s))
              (ctor SumType mn (TyName "T") (CtorName "Other") [refLocal s])
        m =
          moduleOf
            [Standalone (qn "f", mixed)]
            [(Name "main", deconstructingSite f)]
    runCpr mempty m `shouldBe` (m, Unmodified)

  it "declines a self-tail-calling candidate" do
    let looping =
          abstraction (paramNamed s) $
            ifThenElse
              (eq (refLocal s) (literalInt 0))
              (pairOf (literalInt 1) (refLocal s))
              (application f (refLocal s))
        m =
          moduleOf
            [Standalone (qn "f", looping)]
            [(Name "main", deconstructingSite f)]
    runCpr mempty m `shouldBe` (m, Unmodified)

  it "declines the constructor-function shape" do
    -- The Pair$w worker itself: its whole body is the box.
    let ctorWorker =
          abstractionN
            (paramNamed (Name "v0") :| [paramNamed (Name "v1")])
            (pairOf (refLocal (Name "v0")) (refLocal (Name "v1")))
        site =
          lets
            ( Standalone
                ( noAnn
                , Name "v"
                , applicationN f (literalInt 1 :| [literalInt 2])
                )
                :| []
            )
            (dataArgumentByIndex ProductType 0 (refLocal (Name "v")))
        m = moduleOf [Standalone (qn "f", ctorWorker)] [(Name "main", site)]
    runCpr mempty m `shouldBe` (m, Unmodified)

  it "declines without a deconstructing site" do
    -- Both consumers take the product whole: a split would only add an
    -- unbox/rebox hop.
    let m =
          moduleOf
            [Standalone (qn "f", def1)]
            [ (Name "whole", application f (literalInt 7))
            , (Name "stored", lets (bindV (application f (literalInt 8))) (refLocal v))
            ]
    runCpr mempty m `shouldBe` (m, Unmodified)

  it "keeps a whole-value site on the wrapper" do
    let m =
          moduleOf
            [Standalone (qn "f", def1)]
            [ (Name "main", deconstructingSite f)
            , (Name "whole", application f (literalInt 9))
            ]
        (m', rewritten) = runCpr mempty m
    rewritten `shouldBe` Rewritten
    List.lookup (Name "whole") (uberModuleExports m')
      `shouldBe` Just (application f (literalInt 9))

  it "respects the veto" do
    let m =
          moduleOf
            [Standalone (qn "f", def1)]
            [(Name "main", deconstructingSite f)]
    runCpr (Set.singleton (qn "f")) m `shouldBe` (m, Unmodified)

  it "preserves the root annotation on the wrapper" do
    let m =
          moduleOf
            [Standalone (qn "f", setAnn (Just Inline.Always) def1)]
            [(Name "main", deconstructingSite f)]
        (m', _) = runCpr mempty m
    [getRootAnn e | (q, e) ← listGroupings m', q == qn "f"]
      `shouldBe` [Just Inline.Always]

  it "splits a local Let binding in place" do
    let localCandidate =
          lets
            (Standalone (noAnn, Name "g", def1) :| [])
            ( lets
                (bindV (application (refLocal (Name "g")) (literalInt 3)))
                (dataArgumentByIndex ProductType 0 (refLocal v))
            )
        m = moduleOf [] [(Name "main", localCandidate)]
        expected =
          lets
            ( Standalone (noAnn, Name "g$r", worker1)
                :| [Standalone (noAnn, Name "g", localWrapper1)]
            )
            ( lets
                ( bindV
                    ( letValues
                        (paramNamed (Name "$v0") :| [paramNamed (Name "$v1")])
                        ( applicationN
                            (refLocal (Name "g$r"))
                            (literalInt 3 :| [])
                        )
                        (pairOf (refLocal (Name "$v0")) (refLocal (Name "$v1")))
                    )
                )
                (dataArgumentByIndex ProductType 0 (refLocal v))
            )
    runCpr mempty m
      `shouldBe` (moduleOf [] [(Name "main", expected)], Rewritten)

  it "splits a recursive-group member with constructor tails" do
    -- f is ctor-tailed; its sibling g deconstructs f's result. f splits
    -- within the group, worker to the left of its wrapper.
    let site = deconstructingSite f
        gDef = abstraction (paramNamed (Name "n")) site
        m =
          moduleOf
            [RecursiveGroup ((qn "f", def1) :| [(qn "g", gDef)])]
            [(Name "main", application (refImported mn (Name "g")) (literalInt 1))]
        (m', rewritten) = runCpr mempty m
    rewritten `shouldBe` Rewritten
    fmap fst (listGroupings m') `shouldBe` [qn "f$r", qn "f", qn "g"]

  describe "on already-split bindings (rerun)" do
    it "rewrites a new deconstructing site to the existing worker" do
      let m =
            moduleOf
              [ Standalone (qn "f$r", worker1)
              , Standalone (qn "f", wrapper1)
              ]
              [(Name "main", deconstructingSite f)]
          (m', rewritten) = runCpr mempty m
      rewritten `shouldBe` Rewritten
      fmap fst (listGroupings m') `shouldBe` [qn "f$r", qn "f"]
      List.lookup (Name "main") (uberModuleExports m')
        `shouldBe` Just (rewrittenSite ("$v0", "$v1"))

    it "declines a fresh candidate whose worker name is taken" do
      let m =
            moduleOf
              [ Standalone (qn "f$r", literalInt 0)
              , Standalone (qn "f", def1)
              ]
              [(Name "main", deconstructingSite f)]
      runCpr mempty m `shouldBe` (m, Unmodified)

  describe "contract properties (generated modules)" do
    prop 200 "preserves the GUC and WellApplied invariants" do
      (m, veto) ← forAll genModuleAndVeto
      lintAll m === []
      let (m', _) = runCpr veto m
      annotateShow m'
      lintAll m' === []

    prop 200 "is idempotent" do
      (m, veto) ← forAll genModuleAndVeto
      let (m1, _) = runCpr veto m
      annotateShow m1
      runCpr veto m1 === (m1, Unmodified)

    prop 200 "signals Rewritten exactly when the module changed" do
      (m, veto) ← forAll genModuleAndVeto
      let (m', rewritten) = runCpr veto m
      annotateShow m'
      (rewritten == Unmodified) === (m' == m)

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

mn ∷ ModuleName
mn = moduleNameFromString "M"

qn ∷ Text → QName
qn = QName mn . Name

f ∷ Exp
f = refImported mn (Name "f")

s ∷ Name
s = Name "s"

v ∷ Name
v = Name "v"

-- | A saturated in-place application of the product constructor @Pair@.
pairOf ∷ Exp → Exp → Exp
pairOf a b = ctor ProductType mn (TyName "Pair") (CtorName "Pair") [a, b]

{- | @λs. Pair (s == 1) s@ — a unary candidate whose single tail builds
the fixed product (with computed fields, so it is not the degenerate
constructor-function shape).
-}
def1 ∷ Exp
def1 =
  abstraction (paramNamed s) $
    pairOf (eq (refLocal s) (literalInt 1)) (refLocal s)

-- | The worker 'def1' splits into: the tail returns multiple values.
worker1 ∷ Exp
worker1 =
  abstraction (paramNamed s) $
    values (eq (refLocal s) (literalInt 1) :| [refLocal s])

-- | The wrapper @f@ becomes, delegating to the top-level worker.
wrapper1 ∷ Exp
wrapper1 = wrapperOver (refImported mn (Name "f$r")) "f"

-- | The wrapper a local candidate @g@ becomes.
localWrapper1 ∷ Exp
localWrapper1 = wrapperOver (refLocal (Name "g$r")) "g"

wrapperOver ∷ Exp → Text → Exp
wrapperOver workerRef name =
  abstraction (paramNamed (Name (name <> "$p1"))) $
    letValues
      ( paramNamed (Name (name <> "$v1"))
          :| [paramNamed (Name (name <> "$v2"))]
      )
      (applicationN workerRef (refLocal (Name (name <> "$p1")) :| []))
      ( pairOf
          (refLocal (Name (name <> "$v1")))
          (refLocal (Name (name <> "$v2")))
      )

bindV ∷ Exp → NonEmpty Binding
bindV rhs = Standalone (noAnn, v, rhs) :| []

{- | @let v = f 7 in v[0]@ — a saturated call read apart immediately:
the deconstructing site the pass rewrites.
-}
deconstructingSite ∷ Exp → Exp
deconstructingSite callee =
  lets
    (bindV (application callee (literalInt 7)))
    (dataArgumentByIndex ProductType 0 (refLocal v))

{- | The rewritten site: the worker call bound to the two given fresh
names, reboxed in place for the following fixpoint to cancel.
-}
rewrittenSite ∷ (Text, Text) → Exp
rewrittenSite (b1, b2) =
  lets
    ( bindV $
        letValues
          (paramNamed (Name b1) :| [paramNamed (Name b2)])
          ( applicationN
              (refImported mn (Name "f$r"))
              (literalInt 7 :| [])
          )
          (pairOf (refLocal (Name b1)) (refLocal (Name b2)))
    )
    (dataArgumentByIndex ProductType 0 (refLocal v))

moduleOf ∷ [Grouping (QName, Exp)] → [(Name, Exp)] → UberModule
moduleOf bindings exports =
  UberModule
    { uberModuleBindings = bindings
    , uberModuleForeigns = []
    , uberModuleExports = exports
    }

listGroupings ∷ UberModule → [(QName, Exp)]
listGroupings m = do
  grouping ← uberModuleBindings m
  case grouping of
    Standalone b → [b]
    RecursiveGroup bs → toList bs

getRootAnn ∷ Exp → Maybe Inline.Annotation
getRootAnn = \case
  AbsN ann _ _ → ann
  e → error ("getRootAnn: not a lambda: " <> show e)

--------------------------------------------------------------------------------
-- Generators ------------------------------------------------------------------

-- | All three invariant lints the pass's contract set requires.
lintAll ∷ UberModule → [Violation]
lintAll m = lintWellScoped m <> lintUniqueBinders m <> lintWellApplied m

{- | A structurally valid module: 1–3 functions under indexed names
whose bodies end in constructor applications of varying shapes —
single-tail, both-branches, mixed-constructor (a decline case),
non-constructor tails, arity 0–2 — plus 1–3 consumers mixing let-bound
deconstructing reads, whole-value uses and unsaturated calls. Binders
are indexed per site (GUC by construction). Returned together with a
random veto subset of the candidates.
-}
genModuleAndVeto ∷ Gen (UberModule, Set QName)
genModuleAndVeto = do
  candidateCount ← Gen.int (Range.linear 1 3)
  candidates ← forM [1 .. candidateCount] \i → do
    body ← genBody i
    pure (qn ("f" <> show i), abstraction (paramNamed (pname i)) body)
  consumerCount ← Gen.int (Range.linear 1 3)
  consumers ← forM [1 .. consumerCount] \j →
    (Name ("main" <> show j),) <$> genConsumer candidateCount j
  veto ←
    Set.fromList
      <$> Gen.subsequence [q | (q, _) ← candidates]
  pure
    ( UberModule
        { uberModuleBindings = [Standalone c | c ← candidates]
        , uberModuleForeigns = []
        , uberModuleExports = consumers
        }
    , veto
    )
 where
  pname ∷ Int → Name
  pname i = Name ("x" <> show i)

  ctorApp ∷ Int → Text → Int → Exp
  ctorApp i tyCtor arity =
    ctor
      ProductType
      mn
      (TyName tyCtor)
      (CtorName tyCtor)
      (replicate arity (refLocal (pname i)))

  genBody ∷ Int → Gen Exp
  genBody i =
    Gen.choice
      [ -- single ctor tail (arity 0 is a decline case: no fields)
        ctorApp i "P" <$> Gen.int (Range.linear 0 2)
      , -- both branches, same ctor
        pure $
          ifThenElse
            (eq (refLocal (pname i)) (literalInt 0))
            (ctorApp i "P" 2)
            (ctorApp i "P" 2)
      , -- mixed ctors: decline
        pure $
          ifThenElse
            (eq (refLocal (pname i)) (literalInt 0))
            (ctorApp i "P" 2)
            (ctorApp i "Q" 2)
      , -- exception plus ctor
        pure $
          ifThenElse
            (eq (refLocal (pname i)) (literalInt 0))
            (exception "boom")
            (ctorApp i "P" 2)
      , -- non-ctor tail: decline
        pure (eq (refLocal (pname i)) (literalInt 1))
      ]

  genConsumer ∷ Int → Int → Gen Exp
  genConsumer candidateCount j = do
    target ← Gen.int (Range.linear 1 candidateCount)
    let callee = refImported mn (Name ("f" <> show target))
        w = Name ("v" <> show j)
        call = application callee (literalInt (fromIntegral j))
    Gen.choice
      [ -- let-bound deconstructing read: the site shape
        pure $
          lets
            (Standalone (noAnn, w, call) :| [])
            (dataArgumentByIndex ProductType 0 (refLocal w))
      , -- whole-value read
        pure $
          lets
            (Standalone (noAnn, w, call) :| [])
            (refLocal w)
      , -- direct whole-value use
        pure call
      , -- unsaturated (extra application): not a site
        pure (application call (literalInt 0))
      ]
