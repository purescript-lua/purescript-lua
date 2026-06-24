module Language.PureScript.Backend.Lua.Run (runChunk) where

import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Path (toFilePath)
import Path.IO (withSystemTempFile)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderIO)
import System.Exit (ExitCode)
import System.IO (hSetEncoding, utf8)
import System.Process.Typed (proc, runProcess)

{- | Render a Lua chunk to a temporary file and execute it with the @lua@
interpreter found on @PATH@, inheriting the parent's stdin/stdout/stderr and
forwarding the interpreter's exit code verbatim.

This is what makes @pslua@ a runnable Spago backend: for @spago run@, Spago
first builds (the configured backend command emits the linked Lua), then invokes
the backend a second time as @pslua --run <Module>.<entry>@; that second call
compiles the entry point and hands the result here.
-}
runChunk ∷ Lua.Chunk → IO ExitCode
runChunk chunk =
  withSystemTempFile "pslua-run.lua" \file handle → do
    hSetEncoding handle utf8
    renderIO handle . layoutPretty defaultLayoutOptions $
      Printer.printLuaChunk chunk
    hFlush handle
    runProcess (proc "lua" [toFilePath file])
