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
  , PropName (..)
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
  , lets
  , literalInt
  , literalObject
  , noAnn
  , objectProp
  , paramNamed
  , paramUnused
  , refImported
  , refLocal0
  , subexpressions
  )
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Test.Hspec.Hedgehog.Extended (hedgehog, modifyMaxSuccess)

{- | A Hedgehog property run over many examples. The project's
'Test.Hspec.Hedgehog.Extended.test' caps @maxSuccess@ at 1; these invariants are
the correctness insurance for the lambda-lifting core and cheap to check, so they
earn real coverage.
-}
prop ∷ String → PropertyT IO () → Spec
prop title = modifyMaxSuccess (const 200) . it title . hedgehog

spec ∷ Spec
spec = describe "FlattenDeepBinds" do
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

  -- A real `do` block interleaves statement-only lines, which desugar to a
  -- `discard`. For a non-Effect monad the optimizer leaves the discard head as
  -- the `Discard Unit` instance alias `(dict.discard) dictInner` (see
  -- 'discardDef'), NOT collapsed to `bind`. The pass must recognise it, or every
  -- statement splits the chain into one-step fragments that never reach the
  -- threshold. With the discard steps recognised, the whole chain flattens;
  -- without them, no `$kont` helper is introduced.
  it "flattens a chain whose statement lines are discard aliases" do
    let m = discardChainModule 200
        flat = chainExpr (flattenDeepBinds m)
    kontNames flat `shouldSatisfy` (not . null)
    countFreeRefs flat `shouldBe` countFreeRefs (chainExpr m)

  -- The chain-head aliases may land in a RecursiveGroup rather than as
  -- Standalone bindings; the resolver must still find them, or recognition
  -- (and flattening) silently stops.
  it "resolves bind/discard aliases defined in a RecursiveGroup" do
    let flat = chainExpr (flattenDeepBinds (recursiveGroupModule 200))
    kontNames flat `shouldSatisfy` (not . null)

  -- The same for a local bind alias bound in a recursive @let@ group, as
  -- polymorphic code (a bind specialised to a dictionary parameter) can produce.
  it "resolves a local bind alias defined in a RecursiveGroup let" do
    let flat = chainExpr (flattenDeepBinds (letRecursiveGroupModule 200))
    kontNames flat `shouldSatisfy` (not . null)

  -- The invariants the lambda-lifting core must hold for ANY recognised chain —
  -- the property the whole pass rests on, since recognition only governs /which/
  -- chains are restructured, never correctness. Generated chains mix @bind@ and
  -- @discard@ steps, below and above the threshold, with actions and a final
  -- action that reference arbitrary earlier binders (stressing live-set
  -- forwarding).
  describe "properties (generated chains)" do
    prop "preserves free references" do
      e ← forAll genChainExpr
      let flat = chainExpr (flattenDeepBinds (chainModuleOf e))
      countFreeRefs flat === countFreeRefs e

    prop "preserves the number of bind/discard steps" do
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

--------------------------------------------------------------------------------
-- Generated chains ------------------------------------------------------------

-- | A module wrapping @chain@ plus the @bind@ and @discard@ heads it references.
chainModuleOf ∷ Exp → UberModule
chainModuleOf e =
  UberModule
    { uberModuleBindings =
        [ Standalone (bindQName, bindDef)
        , Standalone (discardQName, discardDef)
        , Standalone (QName testModule (Name "chain"), e)
        ]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

{- | A random recognisable chain: each step is a @bind@ (binding @xi@) or a
@discard@ statement line, its action a constant or a reference to an earlier
binder, and the final action compares two earlier binders. Length spans both
sides of the threshold, so both the firing and the left-untouched paths are
exercised. A too-large live set is fine here — the pass then bails, and the
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
        , refLocal0 <$> Gen.element inScope
        ]

  genFinal ∷ [Name] → Gen Exp
  genFinal inScope = case inScope of
    [] → pure (literalInt 0)
    _ →
      eq . refLocal0 <$> Gen.element inScope <*> (refLocal0 <$> Gen.element inScope)

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
    | i > n = pure (refLocal0 (xName 1))
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

-- | Total @bind@ + @discard@ step heads referenced in an expression.
countSteps ∷ Exp → Natural
countSteps e =
  Map.findWithDefault 0 (Imported testModule (Name "bind")) refs
    + Map.findWithDefault 0 (Imported testModule (Name "discard")) refs
 where
  refs = countFreeRefs e

--------------------------------------------------------------------------------
-- A hand-built recognisable bind chain ----------------------------------------

testModule ∷ ModuleName
testModule = moduleNameFromString "Test.Mod"

bindQName ∷ QName
bindQName = QName testModule (Name "bind")

{- | The chain head: a reference to a top-level @bind@ that resolves to a
'Control.Bind.Bind' dictionary's projected method (recognised by its @bind@
and @Apply0@ fields).
-}
bindHead ∷ Exp
bindHead = refImported testModule (Name "bind") 0

bindDef ∷ Exp
bindDef =
  objectProp
    ( literalObject
        [ (PropName "bind", literalInt 0)
        , (PropName "Apply0", literalInt 0)
        ]
    )
    (PropName "bind")

xName ∷ Int → Name
xName i = Name ("x" <> Text.pack (show i))

{- | An @n@-step chain:

> bind a1 (\x1 -> bind a2 (\x2 -> … bind an (\xn -> x1 == xn)))

where @a1 = 0@ and @a_i = x_{i-1} == i@ for @i > 1@ (so each step's action uses
the previous binder), and the final action references @x1@ — forcing the first
binder to be forwarded transitively through every lifted helper.
-}
chainExpr' ∷ Int → Exp
chainExpr' n = go 1
 where
  go ∷ Int → Exp
  go i
    | i > n = eq (refLocal0 (xName 1)) (refLocal0 (xName n))
    | otherwise =
        application
          (application bindHead (action i))
          (abstraction (paramNamed (xName i)) (go (i + 1)))

  action ∷ Int → Exp
  action i
    | i <= 1 = literalInt 0
    | otherwise = eq (refLocal0 (xName (i - 1))) (literalInt (fromIntegral i))

chainModule ∷ Int → UberModule
chainModule n =
  UberModule
    { uberModuleBindings =
        [ Standalone (bindQName, bindDef)
        , Standalone (QName testModule (Name "chain"), chainExpr' n)
        ]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

discardQName ∷ QName
discardQName = QName testModule (Name "discard")

discardHead ∷ Exp
discardHead = refImported testModule (Name "discard") 0

{- | A statement line's @discard@ as the optimizer actually leaves it for a
non-Effect monad: @(dict.discard) dictInner@, where the @Discard Unit@ instance
method is @\dictBind -> Control.Bind.bind dictBind@. Only a full reduction —
field projection then beta — exposes the underlying @Control.Bind.bind@; the
shallow dictionary check cannot, which is exactly what 'headReducesToBind' adds.
-}
discardDef ∷ Exp
discardDef =
  application
    ( objectProp
        ( literalObject
            [
              ( PropName "discard"
              , abstraction
                  (paramNamed (Name "dictBind"))
                  ( application
                      (refImported (moduleNameFromString "Control.Bind") (Name "bind") 0)
                      (refLocal0 (Name "dictBind"))
                  )
              )
            ]
        )
        (PropName "discard")
    )
    (literalInt 0)

{- | An @n@-step chain alternating a @bind@ (odd steps, binding @xi@) with a
@discard@ statement line (even steps, unused binder), as a @State@-style @do@
block of @get@\/@put@ does. The discard head is the alias in 'discardDef', so the
chain flattens only if @discard@ is recognised — otherwise each statement splits
it into one-step fragments below the threshold. The final action reads @x1@,
forcing the first binder through every lifted helper.
-}
discardChainExpr ∷ Int → Exp
discardChainExpr n = go 1
 where
  go ∷ Int → Exp
  go i
    | i > n = eq (refLocal0 (xName 1)) (literalInt 0)
    | even i =
        application
          (application discardHead (literalInt (fromIntegral i)))
          (abstraction paramUnused (go (i + 1)))
    | otherwise =
        application
          (application bindHead (literalInt (fromIntegral i)))
          (abstraction (paramNamed (xName i)) (go (i + 1)))

discardChainModule ∷ Int → UberModule
discardChainModule n =
  UberModule
    { uberModuleBindings =
        [ Standalone (bindQName, bindDef)
        , Standalone (discardQName, discardDef)
        , Standalone (QName testModule (Name "chain"), discardChainExpr n)
        ]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

{- | The @bind@\/@discard@ aliases placed in a 'RecursiveGroup' rather than as
'Standalone' bindings. The resolver must index group members too, otherwise the
aliases do not resolve and the chain silently stops being flattened.
-}
recursiveGroupModule ∷ Int → UberModule
recursiveGroupModule n =
  UberModule
    { uberModuleBindings =
        [ RecursiveGroup ((bindQName, bindDef) :| [(discardQName, discardDef)])
        , Standalone (QName testModule (Name "chain"), discardChainExpr n)
        ]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

localBindName ∷ Name
localBindName = Name "lbind"

-- | An @n@-step bind chain whose head is a @let@-local alias (@lbind@).
localChainExpr ∷ Int → Exp
localChainExpr n = go 1
 where
  go ∷ Int → Exp
  go i
    | i > n = eq (refLocal0 (xName 1)) (literalInt 0)
    | otherwise =
        application
          (application (refLocal0 localBindName) (literalInt (fromIntegral i)))
          (abstraction (paramNamed (xName i)) (go (i + 1)))

{- | The local @bind@ alias bound in a recursive @let@ group, with the chain in
the @let@ body. 'letLocals' must index the group's members, or the local alias
does not resolve and the chain stops being flattened.
-}
letRecursiveGroupModule ∷ Int → UberModule
letRecursiveGroupModule n =
  UberModule
    { uberModuleBindings =
        [ Standalone
            ( QName testModule (Name "chain")
            , lets
                (RecursiveGroup ((noAnn, localBindName, bindDef) :| []) :| [])
                (localChainExpr n)
            )
        ]
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
-- Measures --------------------------------------------------------------------

-- | The longest root-to-leaf path through 'Abs' binders.
maxAbsDepth ∷ Exp → Int
maxAbsDepth e = here + foldl' max 0 (maxAbsDepth <$> toListOf subexpressions e)
 where
  here = case e of Abs {} → 1; _ → 0

-- | Occurrences of the bind head reference.
countBinds ∷ Exp → Natural
countBinds = Map.findWithDefault 0 (Imported testModule (Name "bind")) . countFreeRefs

-- | Names of @$kont@ helper bindings introduced anywhere in the expression.
kontNames ∷ Exp → [Name]
kontNames e =
  [ name
  | sub ← universeOf subexpressions e
  , Let _ binds _ ← [sub]
  , Standalone (_ann, name@(Name t), _def) ← toList binds
  , "$kont" `Text.isPrefixOf` t
  ]
