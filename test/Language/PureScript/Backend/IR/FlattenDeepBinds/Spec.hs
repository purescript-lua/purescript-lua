module Language.PureScript.Backend.IR.FlattenDeepBinds.Spec where

import Control.Lens (toListOf, universeOf)
import Data.Map qualified as Map
import Data.Text qualified as Text
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
  , literalInt
  , literalObject
  , objectProp
  , paramNamed
  , paramUnused
  , refImported
  , refLocal0
  , subexpressions
  )
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

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
