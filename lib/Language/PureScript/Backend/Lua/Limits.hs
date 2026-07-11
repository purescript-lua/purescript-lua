{- | Hard per-function limits of the target Lua VM.

The storage passes ("Language.PureScript.Backend.Lua.Localize") budget
their emission against these limits so that generated chunks stay
loadable on the target (issues #19, #174). The limits are configurable
(@--max-locals@ / @--max-upvalues@) because they differ between Lua
implementations: PUC Lua 5.1 — the floor pslua compiles for, see
@docs/QUIRKS.md@ — ships @LUAI_MAXVARS = 200@ and
@LUAI_MAXUPVALUES = 60@, while e.g. Lua 5.2+ raises the upvalue limit
to 255.
-}
module Language.PureScript.Backend.Lua.Limits
  ( LuaLimits (..)
  , lua51Limits
  , workingLocalCeiling
  , workingUpvalueCeiling
  ) where

-- | Hard per-function limits of the target Lua VM.
data LuaLimits = LuaLimits
  { maxLocals ∷ Int
  {- ^ Local variables per function (@LUAI_MAXVARS@), the chunk's main
  function included.
  -}
  , maxUpvalues ∷ Int
  {- ^ Upvalues per function (@LUAI_MAXUPVALUES@), amplified in Lua 5.1
  by pass-through accumulation: a nested function reading an outer
  local costs an upvalue slot in every intermediate function.
  -}
  }
  deriving stock (Eq, Show)

-- | The Lua 5.1 limits: the compilation floor and the CLI default.
lua51Limits ∷ LuaLimits
lua51Limits = LuaLimits {maxLocals = 200, maxUpvalues = 60}

{- | The locals ceiling the storage passes actually budget against: the
hard limit minus headroom for slots the passes do not model (locals of
hand-written FFI headers, runtime fixtures).
-}
workingLocalCeiling ∷ LuaLimits → Int
workingLocalCeiling LuaLimits {maxLocals} = maxLocals - 20

{- | The upvalue ceiling the storage passes actually budget against:
the hard limit minus headroom, since the passes over-approximate
upvalue demand rather than replicate the target's exact accounting.
-}
workingUpvalueCeiling ∷ LuaLimits → Int
workingUpvalueCeiling LuaLimits {maxUpvalues} = maxUpvalues - 5
