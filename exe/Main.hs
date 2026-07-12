module Main where

import Cli (Args (luaOutputFile), ExtraOutput (..))
import Cli qualified
import Control.Monad.Oops qualified as Oops
import Data.Tagged (Tagged (..))
import Data.Text qualified as Text
import Language.PureScript.Backend (CompilationResult (..))
import Language.PureScript.Backend qualified as Backend
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Pass
  ( PassCheckFailure
  , renderPassCheckFailure
  )
import Language.PureScript.Backend.Lua qualified as Lua
import Language.PureScript.Backend.Lua.ForeignLift qualified as ForeignLift
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Run qualified as Run
import Language.PureScript.Backend.Output (withOutputFile)
import Language.PureScript.CoreFn.Reader qualified as CoreFn
import Language.PureScript.Names (runIdent, runModuleName)
import Main.Utf8 qualified as Utf8
import Path (Abs, Dir, Path, SomeBase (..), replaceExtension, toFilePath)
import Path.IO qualified as Path
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderIO)
import Text.Pretty.Simple (pHPrint)

main ∷ IO ()
main = Utf8.withUtf8 do
  Cli.Args
    { foreignPath
    , luaOutputFile
    , outputIR
    , outputLuaAst
    , lintIR
    , luaLimits
    , psOutputPath
    , appOrModule
    , runEntry
    } ←
    Cli.parseArguments

  foreignDir ∷ Tagged "foreign" (Path Abs Dir) ←
    Tagged
      <$> case unTagged foreignPath of
        Path.Abs a → pure a
        Path.Rel r → Path.makeAbsolute r

  -- `--run` overrides `--entry`: Spago's run phase invokes the backend a second
  -- time as `pslua --run <Entry>` (without the build-phase args), so the entry
  -- to compile comes from `--run` when present.
  let entry = fromMaybe appOrModule runEntry

  let extraOutputs = catMaybes [outputLuaAst, outputIR]

  CompilationResult {lua, ir} ← do
    -- Stay silent in run mode so the program's own stdout isn't polluted (the
    -- output may be piped); Spago already logs the run/build phases itself.
    when (isNothing runEntry) $ putTextLn "PS Lua: compiling ..."
    Backend.compileModules psOutputPath foreignDir lintIR luaLimits entry
      & handleModuleNotFoundError
      & handleModuleDecodingError
      & handleCoreFnError
      & handlePassCheckFailure
      & handleForeignLiftError
      & handleLuaError
      & Oops.runOops

  case runEntry of
    Just _ →
      -- Compile-and-run: execute the linked chunk and exit with lua's code.
      Run.runChunk lua >>= exitWith
    Nothing → do
      luaOutput ←
        case unTagged luaOutputFile of
          Path.Abs a → pure a
          Path.Rel r → Path.makeAbsolute r

      let outputFile = toFilePath luaOutput
      withOutputFile luaOutput \h →
        renderIO h . layoutPretty defaultLayoutOptions $
          Printer.printLuaChunk lua

      when (OutputIR `elem` extraOutputs) do
        irOutputPath ← replaceExtension ".ir" luaOutput
        withOutputFile irOutputPath (`pHPrint` ir)
        putTextLn $ "Wrote IR to " <> toText (toFilePath irOutputPath)

      when (OutputLuaAst `elem` extraOutputs) do
        luaAstOutputPath ← replaceExtension ".lua-ast" luaOutput
        withOutputFile luaAstOutputPath (`pHPrint` lua)
        putTextLn $ "Wrote Lua AST to " <> toText (toFilePath luaAstOutputPath)

      putTextLn $ "Wrote linked modules to " <> toText outputFile

--------------------------------------------------------------------------------
-- Error handlers --------------------------------------------------------------

handleModuleNotFoundError
  ∷ ExceptT (Oops.Variant (CoreFn.ModuleNotFound ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleModuleNotFoundError = Oops.catch \(CoreFn.ModuleNotFound p) →
  die . toString . unlines $
    [ "Can't find CoreFn module file: " <> toText (toFilePath p)
    , "Please make sure you did run purs with the `-g corefn` arg."
    ]

handleModuleDecodingError
  ∷ ExceptT (Oops.Variant (CoreFn.ModuleDecodingErr ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleModuleDecodingError = Oops.catch \(CoreFn.ModuleDecodingErr p e) →
  die . toString . unlines $
    [ "Can't parse CoreFn module file: " <> toText (toFilePath p)
    , toText e
    ]

handleCoreFnError
  ∷ ExceptT (Oops.Variant (IR.CoreFnError ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleCoreFnError =
  Oops.catch \(e ∷ IR.CoreFnError) →
    die $ "CoreFn contains an unexpected value " <> show e

handlePassCheckFailure
  ∷ ExceptT (Oops.Variant (PassCheckFailure ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handlePassCheckFailure =
  Oops.catch (die . toString . renderPassCheckFailure)

handleForeignLiftError
  ∷ ExceptT (Oops.Variant (ForeignLift.Error ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleForeignLiftError =
  Oops.catch \(e ∷ ForeignLift.Error) → die $ "Foreign lift error:\n" <> show e

handleLuaError
  ∷ ExceptT (Oops.Variant (Lua.Error ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleLuaError =
  Oops.catch \case
    Lua.LinkerErrorForeign e →
      die $ "Linker error:\n" <> show e
    Lua.ForeignExportsMissing modname names →
      die . toString . unlines $
        [ "The foreign module for "
            <> runModuleName modname
            <> " does not export: "
            <> Text.intercalate ", " (IR.nameToText <$> toList names)
            <> "."
        , "Every name declared as a `foreign import` in PureScript must be a"
        , "key of the table returned by the module's FFI file."
        ]
    Lua.AppEntryPointNotFound modname ident →
      die . toString $
        "App entry point not found: "
          <> runModuleName modname
          <> "."
          <> runIdent ident
    Lua.NestingTooDeep depth →
      die . toString . unlines $
        [ "Expression nests too deeply for Lua 5.1 ("
            <> show depth
            <> " syntax levels; the parser caps at ~200)."
        , "Deep do/>>=, ado/apply and =<< chains are flattened automatically;"
        , "the remaining causes are large case trees, very wide literals, or a"
        , "single bind chain forwarding too many variables (which makes the"
        , "lambda-lifter bail on Lua's upvalue cap). Split the expression into"
        , "smaller named pieces. See"
        , "https://github.com/purescript-lua/purescript-lua/issues/104 and"
        , "https://github.com/purescript-lua/purescript-lua/issues/108"
        ]
