{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

module Language.PureScript.Backend.Lua.Golden.Spec where

import Control.Monad.Catch (MonadMask)
import Control.Monad.Oops qualified as Oops
import Data.List qualified as List
import Data.String qualified as String
import Data.Tagged (Tagged (..))
import Data.Text qualified as Text
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.FlattenDeepBinds (flattenDeepBinds)
import Language.PureScript.Backend.IR.Linker (LinkMode (..))
import Language.PureScript.Backend.IR.Linker qualified as IR
import Language.PureScript.Backend.IR.Linker qualified as Linker
import Language.PureScript.Backend.IR.Optimizer (optimizedUberModuleChecked)
import Language.PureScript.Backend.Lua qualified as Lua
import Language.PureScript.Backend.Lua.ForeignLift qualified as ForeignLift
import Language.PureScript.Backend.Lua.Limits (LuaLimits, lua51Limits)
import Language.PureScript.Backend.Lua.Optimizer (optimizeChunk)
import Language.PureScript.Backend.Lua.Parser qualified as Parser
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Types (AppOrModule (..))
import Language.PureScript.CoreFn.Reader qualified as CoreFn
import Language.PureScript.Names qualified as PS
import Path
  ( Abs
  , Dir
  , File
  , Path
  , Rel
  , SomeBase (..)
  , dirname
  , filename
  , mkRelDir
  , parent
  , reldir
  , toFilePath
  , (</>)
  )
import Path.IO
  ( AnyPath (makeRelativeToCurrentDir)
  , doesFileExist
  , ensureDir
  , makeAbsolute
  , walkDirAccum
  , withCurrentDir
  )
import Path.Posix (mkRelFile)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import System.FilePath qualified as FilePath
import System.Process.Typed
  ( ExitCode (..)
  , readProcessInterleaved
  , runProcess
  , setWorkingDir
  , shell
  )
import Test.Hspec
  ( Spec
  , beforeAll_
  , describe
  , it
  , runIO
  , shouldBe
  , shouldNotBe
  , shouldSatisfy
  )
import Test.Hspec.Extra (annotatingWith)
import Test.Hspec.Golden (acceptableGolden, defaultGolden)
import Test.Lua (luacParse)
import Text.Pretty.Simple
  ( OutputOptions (..)
  , defaultOutputOptionsNoColor
  , pShowOpt
  )

spec ∷ Spec
spec = do
  describe "Goldens: *.purs -> *.lua" do
    let compilePs = do
          putText "Compiling PureScript sources"
          exitCode ←
            runProcess . setWorkingDir "test/ps" . shell $
              -- Spago >= 0.93 manages codegen itself and rejects `--codegen`
              -- in --purs-args; the `backend` in test/ps/spago.yaml is what
              -- makes it emit CoreFn (see that file for the rationale).
              String.unwords ["spago", "build"]
          exitCode `shouldBe` ExitSuccess
        psOutputPath = $(mkRelDir "test/ps/output/")

    describe "compiles corefn files to lua" $ beforeAll_ compilePs do
      runIO $ ensureDir psOutputPath
      corefns ← runIO $ collectGoldenCorefns psOutputPath
      it "Finds some corefn files" $ corefns `shouldNotBe` mempty
      for_ corefns \corefn → do
        let modulePath = parent corefn
            moduleName =
              PS.ModuleName
                . toText
                . FilePath.dropTrailingPathSeparator
                . toFilePath
                $ dirname modulePath
        -- IR golden
        let irGolden = modulePath </> $(mkRelFile "golden.ir")
        let irActual = modulePath </> $(mkRelFile "actual.ir")
        irTestName ← runIO do
          toFilePath <$> makeRelativeToCurrentDir irGolden
        it irTestName do
          acceptableGolden irGolden (Just irActual) do
            uberModule ← compileCorefn (Tagged (Rel psOutputPath)) moduleName
            pure . toStrict $
              pShowOpt
                defaultOutputOptionsNoColor
                  { outputOptionsIndentAmount = 2
                  , outputOptionsPageWidth = 100
                  , outputOptionsCompact = True
                  }
                uberModule
        -- lua golden
        let evalGolden =
              modulePath </> $(mkRelDir "eval") </> $(mkRelFile "golden.txt")
        let luaGolden = modulePath </> $(mkRelFile "golden.lua")
        let luaActual = modulePath </> $(mkRelFile "actual.lua")
        luaTestName ← runIO do
          toFilePath <$> makeRelativeToCurrentDir luaGolden
        it luaTestName do
          acceptableGolden luaGolden (Just luaActual) do
            appOrModule ←
              doesFileExist evalGolden <&> \case
                True → AsApplication moduleName (PS.Ident "main")
                False → AsModule moduleName
            cfn ← compileCorefn (Tagged (Rel psOutputPath)) moduleName
            compileIr appOrModule lua51Limits cfn

    describe "golden files should evaluate" do
      let
        collectEvaluatableLuas ∷ MonadIO m ⇒ Path Rel Dir → m [Path Abs File]
        collectEvaluatableLuas = walkDirAccum Nothing \_dir _subdirs files →
          pure [file | file ← files, toFilePath (filename file) == "golden.txt"]

      luas ← runIO do collectEvaluatableLuas psOutputPath
      for_ luas \lua → do
        let evalDir = parent lua
        let resActual = evalDir </> $(mkRelFile "actual.txt")
        let resGolden = evalDir </> $(mkRelFile "golden.txt")
        let luaGolden = parent evalDir </> $(mkRelFile "golden.lua")
        luaTestName ← runIO do makeRelativeToCurrentDir lua
        it (toFilePath luaTestName) do
          defaultGolden resGolden (Just resActual) do
            let process = fromString $ "lua " ++ toFilePath luaGolden
            (exitCode, out) ← readProcessInterleaved process
            let niceOut =
                  decodeUtf8 out
                    & lines
                    & fmap Text.stripStart
                    & filter (not . Text.null)
                    & unlines
                    & toString
            exitCode `shouldBe` ExitSuccess `annotatingWith` niceOut
            pure $ toText niceOut

    describe "golden files should typecheck" do
      luas ← runIO do collectLuas psOutputPath
      for_ luas \lua → do
        luaFileName ← runIO do makeRelativeToCurrentDir lua
        it (toFilePath luaFileName) do
          let process =
                fromString . List.unwords $
                  [ "luacheck"
                  , "--quiet"
                  , "--std min"
                  , "--no-color"
                  , "--no-unused" -- TODO: harden eventually
                  , "--no-redefined" -- generated code shadows freely (e.g.
                  -- inlined library fallbacks reusing a parameter name)
                  , "--no-max-line-length"
                  , "--formatter plain"
                  , "--allow-defined"
                  , toFilePath lua
                  ]
          (exitCode, out) ← readProcessInterleaved process
          let niceOut =
                decodeUtf8 out
                  & lines
                  & fmap Text.stripStart
                  & filter (not . Text.null)
                  & unlines
                  & toString
          exitCode `shouldBe` ExitSuccess `annotatingWith` niceOut

  -- The bug #108 fixes, reproduced at the generated-Lua level. A deep
  -- applicative spine (`apply (apply (apply m a) b) c …`) keeps its depth in
  -- the first-argument position, so it codegens to a deeply *nested* Lua
  -- expression. Compiled WITHOUT the deep-nesting pass it must fail to load
  -- with Lua's parser-nesting error; WITH `flattenDeepBinds` it must load.
  -- This is the red-before-green check the goldens alone don't give (the golden
  -- harness always runs the full optimizer, so it only ever shows the fixed
  -- output).
  describe "deep apply spine vs Lua's parser-nesting cap (#108)" do
    it
      "crashes Lua's parser by nesting (not the 200-local cap), and Strategy B fixes it"
      do
        let psModname = PS.ModuleName "Golden.ApplySpine.Test"
            uber = applySpineUberModule 300
        nested ← compileIr (AsModule psModname) lua51Limits uber
        flat ←
          compileIr (AsModule psModname) lua51Limits (flattenDeepBinds uber)

        -- The error message below is the real discriminator: `luac` reports
        -- "too many syntax levels" (nesting), a distinct message from its locals
        -- error ("too many local variables"). As corroboration, the unflattened
        -- spine is a single nested expression that introduces almost no locals,
        -- so it sits far below Lua's 200-locals-per-function cap — that cap
        -- cannot be why it fails to load. (A loose bound, not == 1, to stay
        -- robust to unrelated module/runtime-setup locals the emitter may add.)
        Text.count "local " nested `shouldSatisfy` (< 50)

        (nestedExit, nestedOut) ← luacParse nested
        (flatExit, _flatOut) ← luacParse flat

        nestedExit `shouldSatisfy` (/= ExitSuccess)
        nestedOut `shouldSatisfy` ("too many syntax levels" `Text.isInfixOf`)
        -- The fix segments the spine into a handful of `$tmp` locals, so the same
        -- expression now parses (and uses more than the single module `local`).
        flatExit `shouldBe` ExitSuccess
        Text.count "local " flat `shouldSatisfy` (> 1)

{- | A deep applicative spine @apply (apply (apply 0 1) 2) … n@ as a single
module binding @compute@ — depth in the callee-argument position, so it
generates deeply nested Lua. Used to reproduce the parser-nesting crash.
-}
applySpineUberModule ∷ Int → Linker.UberModule
applySpineUberModule n =
  IR.UberModule
    { IR.uberModuleBindings =
        [IR.Standalone (IR.QName modname (IR.Name "compute"), spine)]
    , IR.uberModuleForeigns = []
    , IR.uberModuleExports = []
    }
 where
  modname = IR.moduleNameFromString "Golden.ApplySpine.Test"
  applyHead = IR.Ref IR.noAnn (IR.Imported modname (IR.Name "apply"))
  spine = foldl' step (IR.LiteralInt IR.noAnn 0) [1 .. n]
  step ∷ IR.Exp → Int → IR.Exp
  step acc i =
    IR.App
      IR.noAnn
      (IR.App IR.noAnn applyHead acc)
      (IR.LiteralInt IR.noAnn (fromIntegral i))

{- | Corefn files that participate in golden tests: only Golden.* modules.
Other modules compiled from test/ps/src pass through uncollected —
bench/link relies on this to link the Bench.* corefns without them
entering the suite.
-}
collectGoldenCorefns ∷ MonadIO m ⇒ Path Rel Dir → m [Path Abs File]
collectGoldenCorefns = walkDirAccum
  Nothing -- Descend into every directory
  \dir _subdirs files →
    pure
      [ file
      | file ← files
      , toFilePath (filename file) == "corefn.json"
      , "Golden." `isPrefixOf` toFilePath (dirname dir)
      ]

collectLuas ∷ MonadIO m ⇒ Path Rel Dir → m [Path Abs File]
collectLuas = walkDirAccum
  Nothing -- Descend into every directory
  \_dir _subdirs files →
    pure [file | file ← files, toFilePath (filename file) == "golden.lua"]

compileCorefn
  ∷ ∀ m
   . (MonadIO m, MonadFail m)
  ⇒ Tagged "output" (SomeBase Dir)
  → PS.ModuleName
  → m IR.UberModule
compileCorefn outputDir uberModuleName = do
  cfnModules ←
    CoreFn.readModuleRecursively outputDir uberModuleName
      & handleModuleNotFoundError
      & handleModuleDecodingError
      & Oops.runOops
      & liftIO

  let dataDecls = IR.collectDataDeclarations cfnModules
  modules ←
    forM (toList cfnModules) $
      either (fail . show) (pure . snd) . \cfnModule →
        IR.mkModule mempty cfnModule dataDecls
  let uberModule = Linker.makeUberModule (LinkAsModule uberModuleName) modules
  -- Lift the allowlisted foreign exports to IR primops (issue #178) exactly
  -- as Backend.compileModules does, so the .ir goldens reflect the same
  -- pipeline. Foreign paths recorded in the CoreFn are relative to test/ps
  -- (the spago build dir), so resolve them from there, mirroring compileIr.
  liftedModule ← liftIO $ withCurrentDir [reldir|test/ps|] do
    foreignPath ← Tagged <$> makeAbsolute [reldir|foreign|]
    ForeignLift.liftForeigns foreignPath uberModule
      & handleForeignLiftError
      & Oops.runOops
  -- The checked runner lints every pass boundary (including every fixpoint
  -- iteration), so each golden module doubles as a scope-invariant test of
  -- the whole pipeline.
  either (fail . show) pure (optimizedUberModuleChecked liftedModule)

compileIr
  ∷ (MonadIO m, MonadMask m)
  ⇒ AppOrModule
  → LuaLimits
  → IR.UberModule
  → m Text
compileIr appOrModule limits uberModule = withCurrentDir [reldir|test/ps|] do
  foreignPath ← Tagged <$> makeAbsolute [reldir|foreign|]
  luaChunk ←
    Lua.fromUberModule foreignPath (Tagged True) appOrModule uberModule
      & handleLuaError
      & Oops.runOops
      & liftIO

  let doc =
        luaChunk
          & optimizeChunk limits
          & Printer.printLuaChunk
  let addTrailingLf = (<> "\n")
  let rendered = addTrailingLf $ renderStrict $ layoutPretty defaultLayoutOptions doc
  -- Everything the codegen prints must be readable back by the compiler's
  -- own Lua parser (#173): the golden corpus doubles as its round-trip
  -- fixture (luacheck separately vouches for third-party parseability).
  liftIO $
    either (fail . Parser.renderParseError) (const pass) $
      Parser.parseChunk "<rendered>" rendered
  pure rendered

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
    ["Can't parse CoreFn module file: " <> toText (toFilePath p), toText e]

handleLuaError
  ∷ ExceptT (Oops.Variant (Lua.Error ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleLuaError = Oops.catch \(e ∷ Lua.Error) → die $ show e

handleForeignLiftError
  ∷ ExceptT (Oops.Variant (ForeignLift.Error ': e)) IO a
  → ExceptT (Oops.Variant e) IO a
handleForeignLiftError = Oops.catch \(e ∷ ForeignLift.Error) → die $ show e
