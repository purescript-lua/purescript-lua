{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Renumber.Spec where

import Control.Monad.Oops (Variant)
import Data.String.Interpolate (__i)
import Data.Tagged (Tagged (..))
import Hedgehog (Gen, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.Lua qualified as Lua
import Language.PureScript.Backend.Lua.Gen qualified as LuaGen
import Language.PureScript.Backend.Lua.Limits (lua51Limits)
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Optimizer (optimizeChunk)
import Language.PureScript.Backend.Lua.Parser (unsafeParseStatements)
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Renumber (renumberChunk)
import Language.PureScript.Backend.Lua.Types qualified as Lua.Types
import Language.PureScript.Backend.Types (AppOrModule (AsModule))
import Path.IO (getCurrentDir)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import Test.Hspec (Expectation, Spec, describe, it)
import Test.Hspec.Expectations.Pretty (shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)

spec ∷ Spec
spec = describe "Lua emission-time renumbering (issue #306)" do
  describe "emitted text is invariant under name-supply history" do
    it "suffix-minted local names (x$N)" do
      base ← emit (letWithMintedLocals 0)
      shifted ← emit (letWithMintedLocals 100)
      shifted `shouldBe` base

    it "recursive-group members and their derived dispatcher names" do
      base ← emit (letRecMutualGroup 0)
      shifted ← emit (letRecMutualGroup 100)
      shifted `shouldBe` base

  describe "renumberChunk" do
    it "renumbers a suffix-minted binder and its references" do
      [__i|
        local x_S_223 = 1
        local y_S_223 = x_S_223
        return x_S_223 + y_S_223
      |]
        `renumbersTo` [__i|
          local x_S_0 = 1
          local y_S_0 = x_S_0
          return x_S_0 + y_S_0
        |]

    it "allocates per base name in first-occurrence order" do
      [__i|
        local v_S_1437 = 1
        local v_S_921 = v_S_1437
        return v_S_921
      |]
        `renumbersTo` [__i|
          local v_S_0 = 1
          local v_S_1 = v_S_0
          return v_S_1
        |]

    it "renumbers a prefix-minted binder ($tagN)" do
      [__i|
        local _S_cse1413 = f()
        return _S_cse1413 + _S_cse1413
      |]
        `renumbersTo` [__i|
          local _S_cse0 = f()
          return _S_cse0 + _S_cse0
        |]

    it "keeps a derived dispatcher name in step with the member it embeds" do
      [__i|
        local even_S_14_S_loop
        local even_S_14
        even_S_14_S_loop = function(_S_sel3, _S_a4)
          return even_S_14(_S_a4)
        end
        even_S_14 = function(n_S_9) return even_S_14_S_loop(1, n_S_9) end
        return even_S_14
      |]
        `renumbersTo` [__i|
          local even_S_0_S_loop
          local even_S_0
          even_S_0_S_loop = function(_S_sel0, _S_a0)
            return even_S_0(_S_a0)
          end
          even_S_0 = function(n_S_0) return even_S_0_S_loop(1, n_S_0) end
          return even_S_0
        |]

    it "renumbers same-named binders of sibling scopes consistently" do
      [__i|
        local f = function(v_S_9) return v_S_9 end
        local g = function(v_S_10) return v_S_10 end
        return f(g(1))
      |]
        `renumbersTo` [__i|
          local f = function(v_S_0) return v_S_0 end
          local g = function(v_S_1) return v_S_1 end
          return f(g(1))
        |]

    it "scopes the until-condition to the repeat body's locals" do
      [__i|
        repeat
          local x_S_9 = 1
        until x_S_9 > 0
      |]
        `renumbersTo` [__i|
          repeat
            local x_S_0 = 1
          until x_S_0 > 0
        |]

    it "skips an index whose spelling occurs as a global" do
      [__i|
        local x_S_5 = 1
        return x_S_5 + x_S_0
      |]
        `renumbersTo` [__i|
          local x_S_1 = 1
          return x_S_1 + x_S_0
        |]

    it "leaves names without a supply-drawn run alone" do
      unchanged
        [__i|
          local add3 = 1
          local pong_S_sc1Tuple = 2
          local x_S_w = 3
          return add3 + pong_S_sc1Tuple + x_S_w
        |]

    it "leaves field names, table keys and global references alone" do
      unchanged
        [__i|
          local M = {}
          M.field_S_5 = { key_S_7 = global_S_3 }
          return M.field_S_5.key_S_7
        |]

    prop 300 "is the identity on chunks without supply-drawn names" do
      chunk ← forAll (fmap Lua.Types.unAnn <$> LuaGen.block)
      renumberChunk chunk === chunk

    prop 300 "is idempotent" do
      chunk ← forAll genMintedChunk
      renumberChunk (renumberChunk chunk) === renumberChunk chunk

--------------------------------------------------------------------------------
-- Chunk generator with supply-minted names ------------------------------------

{- | Statements over a pool of names in the compiler-minted shapes (and
plain ones), some bound, some left free — enough structure to exercise
allocation order, scope threading and the free-name capture guard.
The generated chunks need not be executable Lua; the pass is
grammar-agnostic.
-}
genMintedChunk ∷ Gen Lua.Types.Chunk
genMintedChunk = do
  pool ← Gen.list (Range.linear 2 8) genPoolName
  Gen.list (Range.linear 1 8) (genStatement pool)
 where
  genPoolName ∷ Gen Name
  genPoolName = do
    base ← Name.toText <$> LuaGen.name
    ix ← show <$> Gen.integral (Range.linear 0 9999 ∷ Range.Range Natural)
    Name.unsafeName
      <$> Gen.element
        [ base <> "_S_" <> ix
        , "_S_" <> base <> ix
        , base <> "_S_" <> ix <> "_S_loop"
        , base
        ]

  genStatement ∷ [Name] → Gen Lua.Types.Statement
  genStatement pool =
    Gen.recursive
      Gen.choice
      [ Lua.Types.local1 <$> genPool <*> genRef
      , Lua.Types.assignVar <$> genPool <*> genRef
      , Lua.Types.Return . pure . Lua.Types.ann <$> genRef
      ]
      [ Lua.Types.Do <$> genBlock
      , Lua.Types.LocalFunction
          <$> genPool
          <*> (pure . Lua.Types.ann . Lua.Types.ParamNamed <$> genPool)
          <*> genBlock
      , Lua.Types.ForNum
          <$> genPool
          <*> pure (Lua.Types.ann (Lua.Types.Integer 1))
          <*> pure (Lua.Types.ann (Lua.Types.Integer 3))
          <*> pure Nothing
          <*> genBlock
      ]
   where
    genPool = Gen.element pool
    genRef = Lua.Types.varName <$> genPool
    genBlock =
      fmap Lua.Types.ann <$> Gen.list (Range.linear 0 3) (genStatement pool)

--------------------------------------------------------------------------------
-- Fixtures --------------------------------------------------------------------

{- | A name as the IR passes mint them: @base$N@ with @N@ drawn from the
pipeline-global supply. The offset added to every index in a fixture stands
for supply consumed earlier in the pipeline by unrelated code.
-}
minted ∷ Text → Natural → IR.Name
minted base k = IR.Name (base <> "$" <> show k)

mintedRef ∷ Text → Natural → IR.Exp
mintedRef base k = IR.Ref IR.noAnn (IR.Local (minted base k))

{- | @let v$k = 1; f$(k+1) = \x$(k+2) → x$(k+2) in f$(k+1) v$k@ — standalone
bindings whose names all carry supply indices.
-}
letWithMintedLocals ∷ Natural → IR.Exp
letWithMintedLocals k =
  IR.Let
    IR.noAnn
    ( IR.Standalone (IR.noAnn, minted "v" k, IR.LiteralInt IR.noAnn 1)
        :| [ IR.Standalone
               ( IR.noAnn
               , minted "f" (k + 1)
               , IR.Abs
                   IR.noAnn
                   (IR.ParamNamed IR.noAnn (minted "x" (k + 2)))
                   (mintedRef "x" (k + 2))
               )
           ]
    )
    (IR.App IR.noAnn (mintedRef "f" (k + 1)) (mintedRef "v" k))

{- | A local recursive group of two mutually tail-calling members with
supply-suffixed names. Loopification lowers the cycle to a dispatcher whose
name embeds the leader's supply index mid-name (@even$k$loop@), plus
codegen-fresh selector/slot locals — the derived-name shapes.
-}
letRecMutualGroup ∷ Natural → IR.Exp
letRecMutualGroup k =
  IR.Let
    IR.noAnn
    ( IR.RecursiveGroup
        ( (IR.noAnn, minted "even" k, tailCallTo "odd" (k + 1) (k + 2))
            :| [(IR.noAnn, minted "odd" (k + 1), tailCallTo "even" k (k + 3))]
        )
        :| []
    )
    (IR.App IR.noAnn (mintedRef "even" k) (IR.LiteralInt IR.noAnn 7))
 where
  tailCallTo other i j =
    IR.Abs
      IR.noAnn
      (IR.ParamNamed IR.noAnn (minted "n" j))
      (IR.App IR.noAnn (mintedRef other i) (mintedRef "n" j))

--------------------------------------------------------------------------------
-- Helper Functions ------------------------------------------------------------

{- | Emit a module exporting the expression, through the same
codegen → 'optimizeChunk' → printer path 'Backend.compileModules' uses.
-}
emit ∷ IR.Exp → IO Text
emit expr = do
  foreignPath ← Tagged <$> getCurrentDir
  result ←
    runExceptT
      ( Lua.fromUberModule
          foreignPath
          (Tagged False)
          (AsModule testModuleName)
          uberModule
          ∷ ExceptT (Variant '[Lua.Error]) IO Lua.Types.Chunk
      )
  case result of
    Left err → fail (show err)
    Right chunk →
      pure . renderStrict . layoutPretty defaultLayoutOptions $
        Printer.printLuaChunk (optimizeChunk lua51Limits chunk)
 where
  uberModule =
    UberModule
      { uberModuleBindings = []
      , uberModuleForeigns = []
      , uberModuleExports = [(IR.Name "value", expr)]
      }

testModuleName ∷ IR.ModuleName
testModuleName = IR.ModuleName "Test.Renumber"

render ∷ Lua.Types.Chunk → Text
render =
  renderStrict . layoutPretty defaultLayoutOptions . Printer.printLuaChunk

renumbersTo ∷ HasCallStack ⇒ Text → Text → Expectation
renumbersTo source expected =
  render (renumberChunk (unsafeParseStatements source))
    `shouldBe` render (unsafeParseStatements expected)

unchanged ∷ HasCallStack ⇒ Text → Expectation
unchanged source = source `renumbersTo` source
