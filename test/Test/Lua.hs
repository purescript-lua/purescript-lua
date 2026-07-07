{- | Access to the reference Lua toolchain (@luac@, @lua@) — the external
arbiter for generated Lua: unlike the compiler's own parser, it cannot share
a bug with the printer.
-}
module Test.Lua
  ( luacParse
  , runLuaFile
  ) where

import Data.Text.IO qualified as Text.IO
import Path (toFilePath)
import Path.IO (withSystemTempFile)
import System.Process.Typed
  ( ExitCode
  , ProcessConfig
  , proc
  , readProcessInterleaved
  )

{- | Parse-check (no execution) a Lua source with @luac -p@; returns the exit
code and combined output. Writes to a unique auto-cleaned temp file and
invokes @luac@ via 'proc' (an argv list, no shell), so it is portable and
safe against paths with spaces or concurrent runs.
-}
luacParse ∷ Text → IO (ExitCode, Text)
luacParse = withLuaTempFile \file → proc "luac" ["-p", file]

{- | Run a Lua source with the @lua@ interpreter; returns the exit code and
combined output. Same temp-file pattern as 'luacParse'.
-}
runLuaFile ∷ Text → IO (ExitCode, Text)
runLuaFile = withLuaTempFile \file → proc "lua" [file]

withLuaTempFile
  ∷ (FilePath → ProcessConfig () () ())
  → Text
  → IO (ExitCode, Text)
withLuaTempFile mkProcess src =
  withSystemTempFile "pslua-test.lua" \file handle → do
    -- Write through the handle the bracket owns and flush (so the separate
    -- process sees the bytes); the bracket closes it on cleanup.
    Text.IO.hPutStr handle src
    hFlush handle
    (code, out) ← readProcessInterleaved (mkProcess (toFilePath file))
    pure (code, decodeUtf8 out)
