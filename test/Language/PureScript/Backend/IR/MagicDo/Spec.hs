module Language.PureScript.Backend.IR.MagicDo.Spec where

import Control.Lens (universeOf)
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.MagicDo (magicDo)
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (..)
  , PropName (..)
  , QName (..)
  , discardName
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Binding
  , Exp
  , Grouping (..)
  , RawExp (..)
  , abstraction
  , application
  , lets
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , subexpressions
  , pattern EffectRunArg
  )
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

-- | Run the pass on a module of one binding and return that binding.
lower ∷ Exp → Exp
lower = lowerWith []

-- | Like 'lower', with extra top-level bindings visible to the pass.
lowerWith ∷ [(QName, Exp)] → Exp → Exp
lowerWith extra e = chainExpr (magicDo (moduleOf extra e))

spec ∷ Spec
spec = describe "MagicDo" do
  describe "recognises canonical Effect/ST heads" do
    it "lowers a chain headed by the canonical foreign reference" do
      let chain =
            bindStep effBindE m1 x $
              discardStep effBindE m2 lastAction
      lower chain
        `shouldBe` thunk
          ( lets
              (stmt x m1 :| [stmt discardName m2])
              (run lastAction)
          )

    it "lowers a chain headed by the dissolved foreign-accessor read" do
      let chain = bindStep effBindEAccessor m1 x (refLocal x)
      lower chain
        `shouldBe` thunk (lets (stmt x m1 :| []) (run (refLocal x)))

    it "lowers a chain headed by a one-hop top-level alias" do
      let aliasName = QName testModule (Name "bind1")
          alias = refImported testModule (Name "bind1")
          chain = bindStep alias m1 x (refLocal x)
      lowerWith [(aliasName, effBindE)] chain
        `shouldBe` thunk (lets (stmt x m1 :| []) (run (refLocal x)))

    it "lowers an ST chain by the same canonical names" do
      let chain = bindStep stBind_ m1 x (refLocal x)
      lower chain
        `shouldBe` thunk (lets (stmt x m1 :| []) (run (refLocal x)))

  describe "collapses pure at effect runs (the run peephole)" do
    it "collapses a pure-terminated tail to its argument" do
      let chain = bindStep effBindE m1 x (application effPureE (refLocal x))
      lower chain
        `shouldBe` thunk (lets (stmt x m1 :| []) (refLocal x))

    it "collapses a mid-chain pure statement to a plain local" do
      let chain =
            bindStep effBindE (application effPureE literalOne) x $
              bindStep effBindE m2 y lastAction
      lower chain
        `shouldBe` thunk
          ( lets
              ( Standalone (noAnn, x, literalOne)
                  :| [stmt y m2]
              )
              (run lastAction)
          )

    it "collapses a pre-existing lifted-wrapper run" do
      -- The foreign lifter's run wrappers already mark their thunk run
      -- with 'EffectRunArg'; once the head canonicalizes to pure, the
      -- peephole must fire without any surrounding chain.
      let e = abstraction (paramNamed x) (run (application effPureE (refLocal x)))
      lower e `shouldBe` abstraction (paramNamed x) (refLocal x)

  describe "chunking" do
    it "splits a long chain into at most 150 locals per function" do
      let n = 200
          chain = discardChain n
          flat = lower chain
      flat `shouldSatisfy` (/= chain)
      letSizes flat `shouldSatisfy` all (<= 150)
      sum (letSizes flat) `shouldBe` n

  describe "negatives" do
    it "leaves a chain with a non-lambda continuation alone" do
      let e = application (application effBindE m1) (refImported testModule (Name "k"))
      lower e `shouldBe` e

    it "leaves a non-canonical head for FlattenDeepBinds" do
      let someBind = refImported testModule (Name "someBind")
          e = bindStep someBind m1 x (refLocal x)
      lower e `shouldBe` e

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

testModule ∷ ModuleName
testModule = moduleNameFromString "Test.Module"

effect ∷ ModuleName
effect = moduleNameFromString "Effect"

stInternal ∷ ModuleName
stInternal = moduleNameFromString "Control.Monad.ST.Internal"

effBindE, effPureE, stBind_ ∷ Exp
effBindE = refImported effect (Name "bindE")
effPureE = refImported effect (Name "pureE")
stBind_ = refImported stInternal (Name "bind_")

{- | The shape foreigns take at magic-do time: a field read off the
module's @foreign@ table (see 'foreignAccessorQName').
-}
effBindEAccessor ∷ Exp
effBindEAccessor =
  ObjectProp noAnn (refImported effect (Name "foreign")) (PropName "bindE")

m1, m2, lastAction, literalOne ∷ Exp
m1 = refImported testModule (Name "m1")
m2 = refImported testModule (Name "m2")
lastAction = refImported testModule (Name "last")
literalOne = LiteralInt noAnn 1

x, y ∷ Name
x = Name "x"
y = Name "y"

bindStep ∷ Exp → Exp → Name → Exp → Exp
bindStep hd action name rest =
  application (application hd action) (abstraction (paramNamed name) rest)

discardStep ∷ Exp → Exp → Exp → Exp
discardStep hd action rest =
  application (application hd action) (abstraction paramUnused rest)

discardChain ∷ Int → Exp
discardChain n
  | n <= 0 = lastAction
  | otherwise = discardStep effBindE m1 (discardChain (n - 1))

thunk ∷ Exp → Exp
thunk = abstraction paramUnused

run ∷ Exp → Exp
run e = application e (EffectRunArg noAnn)

stmt ∷ Name → Exp → Binding
stmt name action = Standalone (noAnn, name, run action)

moduleOf ∷ [(QName, Exp)] → Exp → UberModule
moduleOf extra e =
  UberModule
    { uberModuleBindings =
        (Standalone <$> extra)
          <> [Standalone (QName testModule (Name "chain"), e)]
    , uberModuleForeigns = []
    , uberModuleExports = []
    }

chainExpr ∷ UberModule → Exp
chainExpr UberModule {uberModuleBindings} =
  fromMaybe (error "chain binding missing") $
    listToMaybe
      [ e
      | Standalone (QName _ (Name "chain"), e) ← uberModuleBindings
      ]

-- | The binding count of every 'Let' in the expression.
letSizes ∷ Exp → [Int]
letSizes e =
  [ length (toList binds)
  | Let _ binds _ ← universeOf subexpressions e
  ]
