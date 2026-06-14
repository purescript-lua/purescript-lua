module Language.PureScript.Backend.Output
  ( withOutputFile
  ) where

import Path (Abs, File, Path, parent, toFilePath)
import Path.IO (ensureDir)

--------------------------------------------------------------------------------
-- Output ----------------------------------------------------------------------

{- | Open a file for writing, first creating its parent directory (and any
missing ancestors). pslua's @--lua-output-file@ may point into a directory
that does not exist yet (a gitignored @dist/@, say); plain 'withFile' would
abort with @does not exist@, a sharp edge each fork's build script would
otherwise work around with @mkdir -p@.
-}
withOutputFile ∷ Path Abs File → (Handle → IO r) → IO r
withOutputFile path action = do
  ensureDir (parent path)
  withFile (toFilePath path) WriteMode action
