module Language.PureScript.Backend where

import Control.Monad.Oops (CouldBeAnyOf, Variant)
import Control.Monad.Oops qualified as Oops
import Data.Map qualified as Map
import Data.Tagged (Tagged (..), untag)
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Inliner qualified as Inliner
import Language.PureScript.Backend.IR.Linker qualified as Linker
import Language.PureScript.Backend.IR.Optimizer
  ( optimizedUberModule
  , optimizedUberModuleChecked
  )
import Language.PureScript.Backend.IR.Pass (PassCheckFailure)
import Language.PureScript.Backend.Lua qualified as Lua
import Language.PureScript.Backend.Lua.ForeignLift qualified as ForeignLift
import Language.PureScript.Backend.Lua.Limits (LuaLimits)
import Language.PureScript.Backend.Lua.NestingCheck (exceedsNestingLimit)
import Language.PureScript.Backend.Lua.Optimizer (optimizeChunk)
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Language.PureScript.Backend.Types (AppOrModule (..), entryPointModule)
import Language.PureScript.CoreFn.Reader qualified as CoreFn
import Path (Abs, Dir, Path, SomeBase)
import Prelude hiding (show)

data CompilationResult = CompilationResult
  { ir ∷ Linker.UberModule
  , lua ∷ Lua.Chunk
  }

compileModules
  ∷ e
    `CouldBeAnyOf` '[ CoreFn.ModuleNotFound
                    , CoreFn.ModuleDecodingErr
                    , IR.CoreFnError
                    , PassCheckFailure
                    , ForeignLift.Error
                    , Lua.Error
                    ]
  ⇒ Tagged "output" (SomeBase Dir)
  → Tagged "foreign" (Path Abs Dir)
  → Tagged "lint-ir" Bool
  → LuaLimits
  → Inliner.Directives
  → AppOrModule
  → ExceptT (Variant e) IO CompilationResult
compileModules outputDir foreignDir lintIR limits directives appOrModule = do
  let entryModuleName = entryPointModule appOrModule
  cfnModules ← CoreFn.readModuleRecursively outputDir entryModuleName
  let dataDecls = IR.collectDataDeclarations cfnModules
  irResults ← forM (Map.toList cfnModules) \(_psModuleName, cfnModule) →
    Oops.hoistEither $ IR.mkModule directives cfnModule dataDecls
  let (needsRuntimeLazys, irModules) = unzip irResults
  let linkedModule = Linker.makeUberModule (linkerMode appOrModule) irModules
  -- Lift the allowlisted foreign exports to IR primops before optimizing, so
  -- the whole pipeline can see through them (issue #178). DCE later prunes the
  -- foreign source rows thus lifted away.
  liftedModule ← ForeignLift.liftForeigns foreignDir linkedModule
  uberModule ←
    if untag lintIR
      then Oops.hoistEither (optimizedUberModuleChecked dataDecls liftedModule)
      else pure (optimizedUberModule dataDecls liftedModule)
  -- See Note [The PSLUA_runtime_lazy coupling] in Language.PureScript.Names
  let needsRuntimeLazy = Tagged (any untag needsRuntimeLazys)
  chunk ← Lua.fromUberModule foreignDir needsRuntimeLazy appOrModule uberModule
  -- A Lua-level DCE pass used to run here, between codegen and 'optimizeChunk'
  -- (unplugged in 189173d when the IR-level DCE inside 'optimizedUberModule'
  -- took over). The unfinished module is parked on the 'lua-dce-wip' branch;
  -- its known defects are documented there in
  -- Note [Graph-based dead code elimination for Lua].
  let optimizedChunk = optimizeChunk limits chunk
  -- Safety net: reject a chunk that nests too deeply for Lua 5.1's parser
  -- rather than emit Lua that cannot be loaded (issue #104). Catches whatever
  -- 'flattenDeepBinds' bailed on, plus not-yet-flattened deep constructs.
  whenJust (exceedsNestingLimit optimizedChunk) (Oops.throw . Lua.NestingTooDeep)
  pure CompilationResult {lua = optimizedChunk, ir = uberModule}

linkerMode ∷ AppOrModule → Linker.LinkMode
linkerMode = \case
  AsModule psModuleName → Linker.LinkAsModule psModuleName
  AsApplication psModuleName psIdent →
    Linker.LinkAsApplication psModuleName (IR.identToName psIdent)
