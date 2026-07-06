module Language.PureScript.Backend.Lua.Spec where

import Control.Monad.Oops (Variant)
import Control.Monad.Trans.Except (ExceptT, runExceptT)
import Data.Tagged (Tagged (..))
import Data.Text qualified as Text
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.Lua qualified as Lua
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types qualified as Lua.Types
import Language.PureScript.Backend.Types (AppOrModule (AsModule))
import Path.IO (getCurrentDir)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldSatisfy)

spec ∷ Spec
spec = describe "Lua.fromUberModule" do
  it "does not wrap Abs-over-Let body in a scope IIFE" do
    rendered ← compileExportedExpr absWithLetBody
    rendered `shouldSatisfy` (not . Text.isInfixOf "(function()")

  it "does not wrap Abs-over-IfThenElse body in a scope IIFE" do
    rendered ← compileExportedExpr absWithIfBody
    rendered `shouldSatisfy` (not . Text.isInfixOf "(function()")

compileExportedExpr ∷ IR.Exp → IO Text
compileExportedExpr expr = do
  foreignPath ← Tagged <$> getCurrentDir
  let
    moduleName = IR.ModuleName "Test.AbsScopeIife"
    uberModule =
      UberModule
        { uberModuleBindings = []
        , uberModuleForeigns = []
        , uberModuleExports = [(IR.Name "value", expr)]
        }
  result ←
    runExceptT
      ( Lua.fromUberModule
          foreignPath
          (Tagged False)
          (AsModule moduleName)
          uberModule
          ∷ ExceptT (Variant '[Lua.Error]) IO Lua.Types.Chunk
      )
  case result of
    Left _err → expectationFailure "Lua.fromUberModule failed" >> pure ""
    Right chunk →
      pure . renderStrict $
        layoutPretty defaultLayoutOptions (Printer.printLuaChunk chunk)

absWithLetBody ∷ IR.Exp
absWithLetBody =
  IR.Abs
    IR.noAnn
    (IR.ParamNamed IR.noAnn (IR.Name "x"))
    ( IR.Let
        IR.noAnn
        ( IR.Standalone
            ( IR.noAnn
            , IR.Name "y"
            , IR.App
                IR.noAnn
                (IR.Ref IR.noAnn (IR.Local (IR.Name "f")))
                (IR.Ref IR.noAnn (IR.Local (IR.Name "x")))
            )
            :| []
        )
        (IR.Ref IR.noAnn (IR.Local (IR.Name "y")))
    )

absWithIfBody ∷ IR.Exp
absWithIfBody =
  IR.Abs
    IR.noAnn
    (IR.ParamNamed IR.noAnn (IR.Name "x"))
    ( IR.IfThenElse
        IR.noAnn
        (IR.Ref IR.noAnn (IR.Local (IR.Name "p")))
        (IR.Ref IR.noAnn (IR.Local (IR.Name "x")))
        (IR.LiteralInt IR.noAnn 0)
    )
