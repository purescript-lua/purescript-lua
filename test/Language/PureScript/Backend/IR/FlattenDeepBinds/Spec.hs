module Language.PureScript.Backend.IR.FlattenDeepBinds.Spec where

import Control.Lens (toListOf, universeOf)
import Data.Map qualified as Map
import Data.Text qualified as Text
import Hedgehog (Gen, PropertyT, annotate, assert, diff, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.FlattenDeepBinds (flattenDeepBinds)
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , QName (..)
  , Qualified (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , RawExp (..)
  , abstraction
  , application
  , countFreeRefs
  , eq
  , literalInt
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , subexpressions
  )
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Test.Hspec.Hedgehog.Extended (hedgehog, modifyMaxSuccess)

{- | A Hedgehog property run over many examples. The project's
'Test.Hspec.Hedgehog.Extended.test' caps @maxSuccess@ at 1; these invariants are
the correctness insurance for the lambda-lifting and A-normalisation cores and
cheap to check, so they earn real coverage.
-}
prop ∷ String → PropertyT IO () → Spec
prop title = modifyMaxSuccess (const 200) . it title . hedgehog

spec ∷ Spec
spec = describe "FlattenDeepBinds" do
  describe "Strategy A: continuation lambda-lifting" do
    it "leaves short chains untouched (below threshold)" do
      let m = chainModule 10
      flattenDeepBinds m `shouldBe` m

    it "fires on a long chain: introduces $kont helpers" do
      let flat = chainExpr (flattenDeepBinds (chainModule 200))
      kontNames flat `shouldSatisfy` (not . null)

    it "preserves free references (no variable captured or dropped)" do
      let m = chainModule 200
      countFreeRefs (chainExpr (flattenDeepBinds m))
        `shouldBe` countFreeRefs (chainExpr m)

    it "preserves the number of bind applications" do
      let m = chainModule 200
      countBinds (chainExpr (flattenDeepBinds m))
        `shouldBe` countBinds (chainExpr m)

    it "bounds output nesting independently of chain length" do
      -- Two very different chain lengths flatten to the same maximum nesting
      -- depth: the per-segment depth, which does not grow with the chain.
      maxAbsDepth (chainExpr (flattenDeepBinds (chainModule 120)))
        `shouldBe` maxAbsDepth (chainExpr (flattenDeepBinds (chainModule 240)))

    it "drastically reduces nesting depth" do
      let m = chainModule 200
          before = maxAbsDepth (chainExpr m)
          after = maxAbsDepth (chainExpr (flattenDeepBinds m))
      after `shouldSatisfy` (< before)

    it "is idempotent" do
      let once = flattenDeepBinds (chainModule 200)
      flattenDeepBinds once `shouldBe` once

    -- Recognition is purely structural: ANY head whose two-argument application
    -- ends in a lambda is a step, no @Control.Bind@ name or dictionary shape
    -- required. A chain headed by an arbitrary combinator (a @with@/@bracket@
    -- style CPS, here) must therefore flatten just like a @bind@ chain.
    it "flattens a chain whose head is not a bind (structural recognition)" do
      let e = chainExprWith opaqueHead 200
          flat = chainExpr (flattenDeepBinds (chainModuleOf e))
      kontNames flat `shouldSatisfy` (not . null)
      countFreeRefs flat `shouldBe` countFreeRefs e

    -- A real `do` block interleaves statement-only lines (a `discard`, here a
    -- second head). The chain must flatten as one, not split into sub-threshold
    -- fragments at each interleaved head.
    it "flattens a chain interleaving a second head (statement lines)" do
      let m = discardChainModule 200
          flat = chainExpr (flattenDeepBinds m)
      kontNames flat `shouldSatisfy` (not . null)
      countFreeRefs flat `shouldBe` countFreeRefs (chainExpr m)

    -- The invariants the lambda-lifting core must hold for ANY recognised chain.
    -- Generated chains mix two heads, below and above the threshold, with
    -- actions and a final action that reference arbitrary earlier binders
    -- (stressing live-set forwarding).
    describe "properties (generated chains)" do
      prop "preserves free references" do
        e ← forAll genChainExpr
        let flat = chainExpr (flattenDeepBinds (chainModuleOf e))
        countFreeRefs flat === countFreeRefs e

      prop "preserves the number of steps" do
        e ← forAll genChainExpr
        let flat = chainExpr (flattenDeepBinds (chainModuleOf e))
        countSteps flat === countSteps e

      prop "is idempotent" do
        e ← forAll genChainExpr
        let once = flattenDeepBinds (chainModuleOf e)
        flattenDeepBinds once === once

      prop "flattens long chains and reduces nesting" do
        e ← forAll genLongChainExpr
        let flat = chainExpr (flattenDeepBinds (chainModuleOf e))
        annotate ("kont helpers: " <> show (length (kontNames flat)))
        assert (not (null (kontNames flat)))
        diff (maxAbsDepth flat) (<) (maxAbsDepth e)

  describe "Strategy B: application-spine sequentialisation" do
    it "sequentialises a deep left-nested (apply/ado) spine" do
      let e = applyChainExpr 200
          flat = chainExpr (flattenDeepBinds (chainModuleOf e))
      tmpNames flat `shouldSatisfy` (not . null)
      countFreeRefs flat `shouldBe` countFreeRefs e
      maxSpineDepth flat `shouldSatisfy` (< maxSpineDepth e)

    it "sequentialises a deep right-nested (=<<) spine" do
      let e = bindFlippedChainExpr 200
          flat = chainExpr (flattenDeepBinds (chainModuleOf e))
      tmpNames flat `shouldSatisfy` (not . null)
      countFreeRefs flat `shouldBe` countFreeRefs e
      maxSpineDepth flat `shouldSatisfy` (< maxSpineDepth e)

    it "leaves a shallow spine untouched (below threshold)" do
      let m = chainModuleOf (applyChainExpr 10)
      flattenDeepBinds m `shouldBe` m

    it "is idempotent on a deep spine" do
      let once = flattenDeepBinds (chainModuleOf (applyChainExpr 200))
      flattenDeepBinds once `shouldBe` once

    it "bounds output spine depth independently of length" do
      -- Segmented A-normalisation seals a $tmp every `segmentSize` frames, so
      -- the deepest segment nests at most ~`segmentSize` regardless of how deep
      -- the original spine was — bounded, not length-dependent.
      maxSpineDepth
        (chainExpr (flattenDeepBinds (chainModuleOf (applyChainExpr 120))))
        `shouldBe` maxSpineDepth
          (chainExpr (flattenDeepBinds (chainModuleOf (applyChainExpr 240))))

    describe "properties (generated spines)" do
      prop "preserves free references" do
        e ← forAll genSpineExpr
        let flat = chainExpr (flattenDeepBinds (chainModuleOf e))
        countFreeRefs flat === countFreeRefs e

      prop "is idempotent" do
        e ← forAll genSpineExpr
        let once = flattenDeepBinds (chainModuleOf e)
        flattenDeepBinds once === once

      prop "flattens deep spines and reduces nesting" do
        e ← forAll genDeepSpineExpr
        let flat = chainExpr (flattenDeepBinds (chainModuleOf e))
        annotate ("tmp locals: " <> show (length (tmpNames flat)))
        assert (not (null (tmpNames flat)))
        diff (maxSpineDepth flat) (<) (maxSpineDepth e)

--------------------------------------------------------------------------------
-- Module fixtures -------------------------------------------------------------

testModule ∷ ModuleName
testModule = moduleNameFromString "Test.Mod"

-- | Wrap an arbitrary expression as the module's single @chain@ binding.
chainModuleOf ∷ Exp → UberModule
chainModuleOf e =
  UberModule
    { uberModuleBindings = [Standalone (QName testModule (Name "chain"), e)]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

-- | Extract the @chain@ binding's expression from a (possibly flattened) module.
chainExpr ∷ UberModule → Exp
chainExpr UberModule {uberModuleBindings} =
  fromMaybe (error "chain binding missing") $
    listToMaybe
      [ e
      | Standalone (QName _ (Name "chain"), e) ← uberModuleBindings
      ]

--------------------------------------------------------------------------------
-- Strategy A: continuation chains ---------------------------------------------

xName ∷ Int → Name
xName i = Name ("x" <> Text.pack (show i))

-- | A chain head: an arbitrary reference. Recognition does not look at it.
bindHead ∷ Exp
bindHead = refImported testModule (Name "bind")

discardHead ∷ Exp
discardHead = refImported testModule (Name "discard")

-- | A non-@bind@ combinator head, to prove recognition is name-agnostic.
opaqueHead ∷ Exp
opaqueHead = refImported testModule (Name "withResource")

{- | An @n@-step chain headed by @hd@:

> hd a1 (\x1 -> hd a2 (\x2 -> … hd an (\xn -> x1 == xn)))

where @a1 = 0@ and @a_i = x_{i-1} == i@ for @i > 1@ (so each step's action uses
the previous binder), and the final action references @x1@ — forcing the first
binder to be forwarded transitively through every lifted helper.
-}
chainExprWith ∷ Exp → Int → Exp
chainExprWith hd n = go 1
 where
  go ∷ Int → Exp
  go i
    | i > n = eq (refLocal (xName 1)) (refLocal (xName n))
    | otherwise =
        application
          (application hd (action i))
          (abstraction (paramNamed (xName i)) (go (i + 1)))

  action ∷ Int → Exp
  action i
    | i <= 1 = literalInt 0
    | otherwise = eq (refLocal (xName (i - 1))) (literalInt (fromIntegral i))

chainExpr' ∷ Int → Exp
chainExpr' = chainExprWith bindHead

chainModule ∷ Int → UberModule
chainModule = chainModuleOf . chainExpr'

{- | An @n@-step chain alternating two heads: a @bind@ (odd steps, binding @xi@)
with a @discard@ statement line (even steps, unused binder), as a @do@ block of
@get@\/@put@ does. The interleaved head must not split the chain into sub-threshold
fragments. The final action reads @x1@, forcing it through every lifted helper.
-}
discardChainExpr ∷ Int → Exp
discardChainExpr n = go 1
 where
  go ∷ Int → Exp
  go i
    | i > n = eq (refLocal (xName 1)) (literalInt 0)
    | even i =
        application
          (application discardHead (literalInt (fromIntegral i)))
          (abstraction paramUnused (go (i + 1)))
    | otherwise =
        application
          (application bindHead (literalInt (fromIntegral i)))
          (abstraction (paramNamed (xName i)) (go (i + 1)))

discardChainModule ∷ Int → UberModule
discardChainModule = chainModuleOf . discardChainExpr

{- | A random recognisable chain: each step is a @bind@ (binding @xi@) or a
@discard@ statement line, its action a constant or a reference to an earlier
binder, and the final action compares two earlier binders. Length spans both
sides of the threshold, so both the firing and the left-untouched paths are
exercised. A too-large live set is fine — the pass then bails, and the
preservation invariants still hold of the (unchanged) result.
-}
genChainExpr ∷ Gen Exp
genChainExpr = Gen.int (Range.linear 1 120) >>= \n → go 1 n []
 where
  go ∷ Int → Int → [Name] → Gen Exp
  go i n inScope
    | i > n = genFinal inScope
    | otherwise = do
        action ← genAction inScope i
        bindStep ← Gen.bool
        if bindStep
          then do
            let nm = xName i
            rest ← go (i + 1) n (nm : inScope)
            pure
              (application (application bindHead action) (abstraction (paramNamed nm) rest))
          else do
            rest ← go (i + 1) n inScope
            pure
              (application (application discardHead action) (abstraction paramUnused rest))

  genAction ∷ [Name] → Int → Gen Exp
  genAction inScope i = case inScope of
    [] → pure (literalInt (fromIntegral i))
    _ →
      Gen.choice
        [ pure (literalInt (fromIntegral i))
        , refLocal <$> Gen.element inScope
        ]

  genFinal ∷ [Name] → Gen Exp
  genFinal inScope = case inScope of
    [] → pure (literalInt 0)
    _ →
      eq . refLocal <$> Gen.element inScope <*> (refLocal <$> Gen.element inScope)

{- | A long chain (always above the threshold) with a deliberately small live
set — the first step binds @x1@, every other step is a random @bind@\/@discard@
with a constant action, and the final action reads @x1@. This always fires and
never bails on the upvalue budget, so the firing path can be asserted.
-}
genLongChainExpr ∷ Gen Exp
genLongChainExpr =
  Gen.int (Range.linear 60 250) >>= \n → do
    rest ← go 2 n
    pure
      ( application
          (application bindHead (literalInt 1))
          (abstraction (paramNamed (xName 1)) rest)
      )
 where
  go ∷ Int → Int → Gen Exp
  go i n
    | i > n = pure (refLocal (xName 1))
    | otherwise = do
        rest ← go (i + 1) n
        bindStep ← Gen.bool
        pure $
          if bindStep
            then
              application
                (application bindHead (literalInt (fromIntegral i)))
                (abstraction (paramNamed (xName i)) rest)
            else
              application
                (application discardHead (literalInt (fromIntegral i)))
                (abstraction paramUnused rest)

--------------------------------------------------------------------------------
-- Strategy B: application spines ----------------------------------------------

applyHead ∷ Exp
applyHead = refImported testModule (Name "apply")

bindFlippedHead ∷ Exp
bindFlippedHead = refImported testModule (Name "bindFlipped")

{- | A deep left-nested (applicative / @ado@) spine, depth in the callee-argument
position:

> apply (apply (… apply x1 2 …) (n-1)) n
-}
applyChainExpr ∷ Int → Exp
applyChainExpr n = foldl' step (refLocal (xName 1)) [2 .. n]
 where
  step ∷ Exp → Int → Exp
  step acc i = application (application applyHead acc) (literalInt (fromIntegral i))

{- | A deep right-nested (flipped-bind / @=<<@) spine, depth in the
final-argument position:

> bindFlipped 1 (bindFlipped 2 (… bindFlipped n x1 …))
-}
bindFlippedChainExpr ∷ Int → Exp
bindFlippedChainExpr n = go 1
 where
  go ∷ Int → Exp
  go i
    | i > n = refLocal (xName 1)
    | otherwise =
        application
          (application bindFlippedHead (literalInt (fromIntegral i)))
          (go (i + 1))

-- | A deep spine, randomly left- or right-nested, always above the threshold.
genDeepSpineExpr ∷ Gen Exp
genDeepSpineExpr = do
  n ← Gen.int (Range.linear 60 250)
  leftNested ← Gen.bool
  pure (if leftNested then applyChainExpr n else bindFlippedChainExpr n)

-- | A spine spanning both sides of the threshold (firing and untouched paths).
genSpineExpr ∷ Gen Exp
genSpineExpr = do
  n ← Gen.int (Range.linear 1 250)
  leftNested ← Gen.bool
  pure (if leftNested then applyChainExpr n else bindFlippedChainExpr n)

--------------------------------------------------------------------------------
-- Measures --------------------------------------------------------------------

-- | The longest root-to-leaf path through 'Abs' binders.
maxAbsDepth ∷ Exp → Int
maxAbsDepth e = here + foldl' max 0 (maxAbsDepth <$> toListOf subexpressions e)
 where
  here = case e of Abs {} → 1; _ → 0

{- | The deepest contiguous chain of 'App' nodes anywhere in the expression —
the parse nesting Strategy B flattens (mirrors the pass's own @spineDepth@).
-}
maxSpineDepth ∷ Exp → Int
maxSpineDepth e =
  foldl' max 0 (spineDepthAt <$> universeOf subexpressions e)
 where
  spineDepthAt ∷ Exp → Int
  spineDepthAt = \case
    App _ann f a → 1 + max (spineDepthAt f) (spineDepthAt a)
    _ → 0

-- | Occurrences of the @bind@ head reference.
countBinds ∷ Exp → Natural
countBinds = Map.findWithDefault 0 (Imported testModule (Name "bind")) . countFreeRefs

-- | Total @bind@ + @discard@ step heads referenced in an expression.
countSteps ∷ Exp → Natural
countSteps e =
  Map.findWithDefault 0 (Imported testModule (Name "bind")) refs
    + Map.findWithDefault 0 (Imported testModule (Name "discard")) refs
 where
  refs = countFreeRefs e

-- | Names of @$kont@ helper bindings introduced anywhere in the expression.
kontNames ∷ Exp → [Name]
kontNames = bindingNamesWithPrefix "$kont"

-- | Names of @$tmp@ locals introduced anywhere in the expression.
tmpNames ∷ Exp → [Name]
tmpNames = bindingNamesWithPrefix "$tmp"

bindingNamesWithPrefix ∷ Text → Exp → [Name]
bindingNamesWithPrefix prefix e =
  [ name
  | sub ← universeOf subexpressions e
  , Let _ binds _ ← [sub]
  , Standalone (_ann, name@(Name t), _def) ← toList binds
  , prefix `Text.isPrefixOf` t
  ]
