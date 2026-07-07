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

  it "omits the $ctor row for a product-type constructor" do
    rendered ← compileExportedExpr (ctorExpr IR.ProductType)
    rendered `shouldSatisfy` (not . Text.isInfixOf "$ctor")

  it "keeps the $ctor row for a sum-type constructor" do
    rendered ← compileExportedExpr (ctorExpr IR.SumType)
    rendered `shouldSatisfy` Text.isInfixOf "[\"$ctor\"]"

  it "emits one n-ary Lua call for a multi-argument AppN" do
    rendered ← compileExportedExpr naryCall
    -- A single call passing every argument, not a curried f(a)(b)(c) spine.
    rendered `shouldSatisfy` Text.isInfixOf "f(a, b, c)"
    rendered `shouldSatisfy` (not . Text.isInfixOf "f(a)(b)(c)")

  it "emits one n-ary Lua function for a multi-parameter AbsN" do
    rendered ← compileExportedExpr naryAbs
    -- One function binding both parameters, not a curried chain.
    rendered `shouldSatisfy` Text.isInfixOf "function(a, b)"
    rendered `shouldSatisfy` (not . Text.isInfixOf "function(a)")

  it "drops the trailing run of unused AbsN parameters" do
    rendered ← compileExportedExpr naryAbsTrailingUnused
    rendered `shouldSatisfy` Text.isInfixOf "function(a)"
    rendered `shouldSatisfy` (not . Text.isInfixOf "function(a,")

  it "elides the trailing run of Prim.undefined arguments" do
    rendered ← compileExportedExpr (naryCallOn [ref "a", primUndefined])
    rendered `shouldSatisfy` Text.isInfixOf "f(a)"

  it "lowers a non-trailing Prim.undefined argument to nil" do
    rendered ← compileExportedExpr (naryCallOn [primUndefined, ref "b"])
    rendered `shouldSatisfy` Text.isInfixOf "f(nil, b)"

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

-- @f(a, b, c)@: one call, three arguments, head is a plain reference.
naryCall ∷ IR.Exp
naryCall = naryCallOn [ref "a", ref "b", ref "c"]

naryCallOn ∷ [IR.Exp] → IR.Exp
naryCallOn = \case
  arg : args → IR.AppN IR.noAnn (ref "f") (arg :| args)
  [] → error "naryCallOn: needs at least one argument"

ref ∷ Text → IR.Exp
ref = IR.Ref IR.noAnn . IR.Local . IR.Name

primUndefined ∷ IR.Exp
primUndefined =
  IR.Ref IR.noAnn (IR.Imported (IR.ModuleName "Prim") (IR.Name "undefined"))

-- @function(a, b) return a end@: one function, two parameters.
naryAbs ∷ IR.Exp
naryAbs =
  IR.AbsN
    IR.noAnn
    ( IR.ParamNamed IR.noAnn (IR.Name "a")
        :| [IR.ParamNamed IR.noAnn (IR.Name "b")]
    )
    (ref "a")

-- @function(a) return a end@: the trailing unused parameters are dropped.
naryAbsTrailingUnused ∷ IR.Exp
naryAbsTrailingUnused =
  IR.AbsN
    IR.noAnn
    ( IR.ParamNamed IR.noAnn (IR.Name "a")
        :| [IR.ParamUnused IR.noAnn, IR.ParamUnused IR.noAnn]
    )
    (ref "a")

ctorExpr ∷ IR.AlgebraicType → IR.Exp
ctorExpr algebraicTy =
  IR.ctor
    algebraicTy
    (IR.ModuleName "M")
    (IR.TyName "T")
    (IR.CtorName "C")
    [IR.FieldName "value0"]
