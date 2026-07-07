module Language.PureScript.Backend.IR.Uncurry.Spec where

import Data.Set qualified as Set
import Data.Text qualified as Text
import Hedgehog (Gen, annotateShow, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.Inliner qualified as Inline
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( Violation
  , lintUniqueBinders
  , lintWellApplied
  , lintWellScoped
  )
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (..)
  , QName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , RawExp (..)
  , WasRewritten (..)
  , abstraction
  , abstractionN
  , application
  , applicationN
  , eq
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , setAnn
  )
import Language.PureScript.Backend.IR.Uncurry (uncurryWorkerWrapper)
import Test.Hspec (Spec, describe, it, shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)

spec ∷ Spec
spec = describe "IR Uncurry (worker/wrapper)" do
  it "splits a saturated binding into worker and wrapper, rewriting the site" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", saturatedCall)]
    uncurryWorkerWrapper mempty m
      `shouldBe` ( moduleOf
                     [ Standalone (qn "f$w", worker2)
                     , Standalone (qn "f", wrapper2)
                     ]
                     [(Name "main", applicationN fw (literalInt 1 :| [literalInt 2]))]
                 , Rewritten
                 )

  it "leaves a binding with no saturated application untouched" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", application f (literalInt 1))]
    uncurryWorkerWrapper mempty m `shouldBe` (m, Unmodified)

  it "keeps partial applications going through the wrapper" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [ (Name "main", saturatedCall)
            , (Name "partial", application f (literalInt 1))
            ]
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleExports m'
      `shouldBe` [ (Name "main", applicationN fw (literalInt 1 :| [literalInt 2]))
                 , (Name "partial", application f (literalInt 1))
                 ]

  it "rewrites the inner node of an over-application" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", application saturatedCall (literalInt 3))]
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleExports m'
      `shouldBe` [
                   ( Name "main"
                   , application
                       (applicationN fw (literalInt 1 :| [literalInt 2]))
                       (literalInt 3)
                   )
                 ]

  it "uncurries a recursive-group member and its self-call" do
    let body =
          application
            (application f (refLocal (Name "a")))
            (refLocal (Name "b"))
        member =
          abstraction
            (paramNamed (Name "a"))
            (abstraction (paramNamed (Name "b")) body)
        m =
          moduleOf
            [RecursiveGroup ((qn "f", member) :| [])]
            [(Name "main", saturatedCall)]
        workerBody =
          applicationN
            fw
            (refLocal (Name "a") :| [refLocal (Name "b")])
        worker =
          abstractionN
            (paramNamed (Name "a") :| [paramNamed (Name "b")])
            workerBody
    uncurryWorkerWrapper mempty m
      `shouldBe` ( moduleOf
                     [ RecursiveGroup
                         ((qn "f$w", worker) :| [(qn "f", wrapper2)])
                     ]
                     [(Name "main", applicationN fw (literalInt 1 :| [literalInt 2]))]
                 , Rewritten
                 )

  it "uncurries a local Let binding in place" do
    let go = Name "go"
        goDef =
          abstraction
            (paramNamed (Name "a"))
            ( abstraction
                (paramNamed (Name "b"))
                (eq (refLocal (Name "a")) (refLocal (Name "b")))
            )
        site =
          application
            (application (refLocal go) (literalInt 1))
            (literalInt 2)
        m =
          moduleOf
            [Standalone (qn "g", lets (Standalone (noAnn, go, goDef) :| []) site)]
            []
        goWorker =
          abstractionN
            (paramNamed (Name "a") :| [paramNamed (Name "b")])
            (eq (refLocal (Name "a")) (refLocal (Name "b")))
        goWrapper =
          abstraction
            (paramNamed (Name "go$p1"))
            ( abstraction
                (paramNamed (Name "go$p2"))
                ( applicationN
                    (refLocal (Name "go$w"))
                    (refLocal (Name "go$p1") :| [refLocal (Name "go$p2")])
                )
            )
        expected =
          lets
            ( Standalone (noAnn, Name "go$w", goWorker)
                :| [Standalone (noAnn, go, goWrapper)]
            )
            ( applicationN
                (refLocal (Name "go$w"))
                (literalInt 1 :| [literalInt 2])
            )
    uncurryWorkerWrapper mempty m
      `shouldBe` (moduleOf [Standalone (qn "g", expected)] [], Rewritten)

  it "does not split an @inline never binding" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", saturatedCall)]
    uncurryWorkerWrapper (Set.singleton (qn "f")) m
      `shouldBe` (m, Unmodified)

  it "keeps a trailing unused parameter unused in the worker" do
    let def =
          abstraction
            (paramNamed (Name "x"))
            (abstraction paramUnused (refLocal (Name "x")))
        m =
          moduleOf
            [Standalone (qn "f", def)]
            [(Name "main", saturatedCall)]
        worker =
          abstractionN
            (paramNamed (Name "x") :| [paramUnused])
            (refLocal (Name "x"))
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleBindings m'
      `shouldBe` [ Standalone (qn "f$w", worker)
                 , Standalone (qn "f", wrapper2)
                 ]

  it "names an interior unused parameter of the worker" do
    -- ParamUnused must stay a trailing run (Note [n-ary abstraction]),
    -- so an unused parameter followed by a named one becomes a fresh
    -- never-referenced binder.
    let def =
          abstraction
            paramUnused
            (abstraction (paramNamed (Name "y")) (refLocal (Name "y")))
        m =
          moduleOf
            [Standalone (qn "f", def)]
            [(Name "main", saturatedCall)]
        worker =
          abstractionN
            (paramNamed (Name "f$u1") :| [paramNamed (Name "y")])
            (refLocal (Name "y"))
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleBindings m'
      `shouldBe` [ Standalone (qn "f$w", worker)
                 , Standalone (qn "f", wrapper2)
                 ]

  it "preserves the wrapper's root annotation" do
    let m =
          moduleOf
            [Standalone (qn "f", setAnn (Just Inline.Always) def2)]
            [(Name "main", saturatedCall)]
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleBindings m'
      `shouldBe` [ Standalone (qn "f$w", worker2)
                 , Standalone (qn "f", setAnn (Just Inline.Always) wrapper2)
                 ]

  it "scopes local candidates per top-level site" do
    -- Two sites both bind a local `go`: a saturated site in one site
    -- must not qualify the same-named binder of the other site.
    let go = Name "go"
        goDef =
          abstraction
            (paramNamed (Name "a"))
            (abstraction (paramNamed (Name "b")) (refLocal (Name "a")))
        saturated =
          application (application (refLocal go) (literalInt 1)) (literalInt 2)
        partial = application (refLocal go) (literalInt 1)
        siteWith = lets (Standalone (noAnn, go, goDef) :| [])
        m =
          moduleOf
            [ Standalone (qn "g1", siteWith saturated)
            , Standalone (qn "g2", siteWith partial)
            ]
            []
    let (m', _) = uncurryWorkerWrapper mempty m
        exprOf name =
          fromMaybe (error "binding missing") $
            listToMaybe
              [e | Standalone (q, e) ← uberModuleBindings m', q == qn name]
    -- g1's go is split…
    case exprOf "g1" of
      Let _ binds _ → length (toList binds) `shouldBe` 2
      _ → error "g1 lost its Let"
    -- …g2's same-named go is not.
    exprOf "g2" `shouldBe` siteWith partial

  -- The pass's module-level contract, over generated modules (see the
  -- generators below): whatever mix of candidates, vetoes and call
  -- shapes the module holds, the output lints clean, a second run is a
  -- no-op, and the 'WasRewritten' signal is precise.
  describe "contract properties (generated modules)" do
    prop 200 "preserves the GUC and WellApplied invariants" do
      (m, veto) ← forAll genModuleAndVeto
      lintAll m === [] -- generator sanity: the contract starts clean
      let (m', _) = uncurryWorkerWrapper veto m
      annotateShow m'
      lintAll m' === []

    prop 200 "is idempotent" do
      (m, veto) ← forAll genModuleAndVeto
      let (once, _) = uncurryWorkerWrapper veto m
      uncurryWorkerWrapper veto once === (once, Unmodified)

    prop 200 "signals Rewritten exactly when the module changed" do
      (m, veto) ← forAll genModuleAndVeto
      let (m', rewritten) = uncurryWorkerWrapper veto m
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

fw ∷ Exp
fw = refImported mn (Name "f$w")

-- | @λa. λb. a == b@ — the curried two-parameter definition.
def2 ∷ Exp
def2 =
  abstraction
    (paramNamed (Name "a"))
    ( abstraction
        (paramNamed (Name "b"))
        (eq (refLocal (Name "a")) (refLocal (Name "b")))
    )

-- | The worker 'def2' splits into.
worker2 ∷ Exp
worker2 =
  abstractionN
    (paramNamed (Name "a") :| [paramNamed (Name "b")])
    (eq (refLocal (Name "a")) (refLocal (Name "b")))

-- | The wrapper @f@ becomes: @λf$p1. λf$p2. f$w(f$p1, f$p2)@.
wrapper2 ∷ Exp
wrapper2 =
  abstraction
    (paramNamed (Name "f$p1"))
    ( abstraction
        (paramNamed (Name "f$p2"))
        ( applicationN
            fw
            (refLocal (Name "f$p1") :| [refLocal (Name "f$p2")])
        )
    )

-- | @f(1)(2)@ — a saturated curried call of the arity-2 candidate.
saturatedCall ∷ Exp
saturatedCall =
  application (application f (literalInt 1)) (literalInt 2)

moduleOf ∷ [Grouping (QName, Exp)] → [(Name, Exp)] → UberModule
moduleOf bindings exports =
  UberModule
    { uberModuleBindings = bindings
    , uberModuleForeigns = []
    , uberModuleExports = exports
    }

--------------------------------------------------------------------------------
-- Generators ------------------------------------------------------------------

-- | All three invariant lints the pass's contract set requires.
lintAll ∷ UberModule → [Violation]
lintAll m = lintWellScoped m <> lintUniqueBinders m <> lintWellApplied m

{- | A structurally valid module: 1–3 candidate functions of arity 1–3
(arity 1 is the negative case — below the split threshold) under
indexed names, so binders are unique per top-level site (GUC by
construction), and 1–3 consumer expressions mixing saturated, partial
and over-applied call shapes. The first consumer is the @main@ export —
sites in exports are counted too — the rest are bindings. Returned
together with a random @inline never@ veto subset of the candidates.
-}
genModuleAndVeto ∷ Gen (UberModule, Set QName)
genModuleAndVeto = do
  arities ← Gen.nonEmpty (Range.linear 1 3) (Gen.int (Range.linear 1 3))
  let candidates = zip [1 ∷ Int ..] (toList arities)
  candidateBindings ← forM candidates \(i, arity) →
    Standalone . (qn (fnName i),) <$> genCandidateDef i arity
  consumerCount ← Gen.int (Range.linear 1 3)
  consumerExprs ← forM [1 .. consumerCount] (genConsumer candidates)
  veto ←
    Set.fromList . map (qn . fnName . fst) <$> Gen.subsequence candidates
  let consumerBindings =
        [ Standalone (qn ("use" <> Text.pack (show i)), e)
        | (i, e) ← zip [2 ∷ Int ..] (drop 1 consumerExprs)
        ]
      exports = [(Name "main", e) | e ← take 1 consumerExprs]
  pure (moduleOf (candidateBindings <> consumerBindings) exports, veto)

fnName ∷ Int → Text
fnName i = "fn" <> Text.pack (show i)

-- | @λp\<i\>x1. … λp\<i\>xk. body@ — a curried candidate definition.
genCandidateDef ∷ Int → Int → Gen Exp
genCandidateDef i arity = do
  let params =
        [ Name ("p" <> Text.pack (show i) <> "x" <> Text.pack (show j))
        | j ← [1 .. arity]
        ]
  body ← genBody params
  pure (foldr (abstraction . paramNamed) body params)

-- | A small expression over the candidate's own parameters.
genBody ∷ [Name] → Gen Exp
genBody params =
  Gen.choice
    [ ref
    , eq <$> ref <*> ref
    , eq (literalInt 0) <$> ref
    ]
 where
  ref = refLocal <$> Gen.element params

{- | One consumer: 1–3 call shapes of random candidates folded into one
expression, optionally wrapped in a local 'Let' candidate site.
-}
genConsumer ∷ [(Int, Int)] → Int → Gen Exp
genConsumer candidates i = do
  calls ←
    Gen.nonEmpty (Range.linear 1 3) (Gen.element candidates >>= genCallShape)
  let combined = foldl' eq (head calls) (tail calls)
  withLocal ← Gen.bool
  if withLocal then genLocalSite i combined else pure combined

{- | A unary application spine of a candidate: saturated (exactly the
arity), partial (anything below, a bare reference included), or
over-applied (one argument past the arity).
-}
genCallShape ∷ (Int, Int) → Gen Exp
genCallShape (i, arity) = do
  argCount ←
    Gen.choice
      [ pure arity
      , Gen.int (Range.linear 0 (arity - 1))
      , pure (arity + 1)
      ]
  pure $
    foldl'
      application
      (refImported mn (Name (fnName i)))
      [literalInt (fromIntegral j) | j ← [1 .. argCount]]

{- | Wrap a consumer in a local arity-2 candidate with one site of its
own — saturated, partial, or a bare reference.
-}
genLocalSite ∷ Int → Exp → Gen Exp
genLocalSite i body = do
  let suffix = Text.pack (show i)
      go = Name ("go" <> suffix)
      a = Name ("a" <> suffix)
      b = Name ("b" <> suffix)
      goDef =
        abstraction
          (paramNamed a)
          (abstraction (paramNamed b) (eq (refLocal a) (refLocal b)))
  argCount ← Gen.int (Range.linear 0 2)
  let call =
        foldl'
          application
          (refLocal go)
          [literalInt (fromIntegral j) | j ← [1 .. argCount]]
  pure (lets (Standalone (noAnn, go, goDef) :| []) (eq call body))
