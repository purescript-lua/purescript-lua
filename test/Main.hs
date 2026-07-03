module Main where

import Language.PureScript.Backend.IR.DCE.Spec qualified as IrDce
import Language.PureScript.Backend.IR.FlattenDeepBinds.Spec qualified as FlattenDeepBinds
import Language.PureScript.Backend.IR.FloatIn.Spec qualified as FloatIn
import Language.PureScript.Backend.IR.Inliner.Spec qualified as Inliner
import Language.PureScript.Backend.IR.Linker.Spec qualified as IRLinker
import Language.PureScript.Backend.IR.Linter.Spec qualified as IRLinter
import Language.PureScript.Backend.IR.Optimizer.Spec qualified as IROptimizer
import Language.PureScript.Backend.IR.Pass.Spec qualified as IRPass
import Language.PureScript.Backend.IR.Spec qualified as IR
import Language.PureScript.Backend.IR.Types.Spec qualified as Types
import Language.PureScript.Backend.IR.Uniquify.Spec qualified as IRUniquify
import Language.PureScript.Backend.Lua.Golden.Spec qualified as Golden
import Language.PureScript.Backend.Lua.Linker.Foreign.Spec qualified as LuaLinkerForeign
import Language.PureScript.Backend.Lua.NestingCheck.Spec qualified as NestingCheck
import Language.PureScript.Backend.Lua.Optimizer.Spec qualified as LuaOptimizer
import Language.PureScript.Backend.Lua.Printer.Spec qualified as Printer
import Language.PureScript.Backend.Lua.Run.Spec qualified as Run
import Language.PureScript.Backend.Output.Spec qualified as Output
import Test.Hspec (hspec)

main ∷ IO ()
main = hspec do
  IR.spec
  Inliner.spec
  Golden.spec
  IrDce.spec
  Types.spec
  IRLinker.spec
  IRLinter.spec
  IROptimizer.spec
  IRPass.spec
  IRUniquify.spec
  LuaOptimizer.spec
  Printer.spec
  Run.spec
  LuaLinkerForeign.spec
  NestingCheck.spec
  FlattenDeepBinds.spec
  FloatIn.spec
  Output.spec
