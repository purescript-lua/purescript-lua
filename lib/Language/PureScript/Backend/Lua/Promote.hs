{- | Two-tier storage of top-level bindings (issue #174, stage 2).

Placeholder: the pass currently returns the chunk unchanged.
-}
module Language.PureScript.Backend.Lua.Promote
  ( promoteChunk
  ) where

import Language.PureScript.Backend.Lua.Limits (LuaLimits)
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Types (Chunk)

promoteChunk ∷ LuaLimits → Name → Chunk → Chunk
promoteChunk _limits _m chunk = chunk
