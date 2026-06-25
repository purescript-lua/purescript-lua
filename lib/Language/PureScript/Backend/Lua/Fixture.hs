{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Fixture where

import Data.String.Interpolate (__i)
import Language.PureScript.Backend.Lua.Name (Name, name, unsafeName)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Types hiding (var)

--------------------------------------------------------------------------------
-- Hard-coded Lua pieces -------------------------------------------------------

uniqueName ∷ MonadState Natural m ⇒ Text → m Name
uniqueName prefix = do
  index ← get
  modify' (+ 1)
  pure $ unsafeName (prefix <> show index)

psluaName ∷ Name → Name
psluaName = Name.join2 [name|PSLUA|]

moduleName ∷ Name.Name
moduleName = [name|M|]

-- See Note [The PSLUA_runtime_lazy coupling] in Language.PureScript.Names
runtimeLazyName ∷ Name
runtimeLazyName = psluaName [name|runtime_lazy|]

{- Note [The runtimeLazy calling convention]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'runtimeLazy' is the hand-written Lua fixture that the laziness transform
('Language.PureScript.CoreFn.Laziness') calls to build a memoized,
cycle-checked initializer for a recursive binding. The generated code and the
fixture share a fixed curried calling convention:

  PSLUA_runtime_lazy(name)(init)(line)

  * @name@ (string): the identifier being initialized, used only in the
    "<name> was needed before it finished initializing" message.
  * @init@ (thunk): a nullary function holding the binding's initializer.
  * The result is the forcing thunk, bound to the lazy name. Each force is
    applied to one argument that the fixture ignores; the transform currently
    hardcodes it to 0 (see 'makeForceCall'). In the JS backend this argument is
    the reference's line number, used in the loop error message.

'state' and 'val' live in the @function(init)@ closure, not in the forcing
thunk, so they persist across forces: 'state' moves 0 (unforced) -> 1
(forcing) -> 2 (done), and a force that re-enters while 'state' is 1 raises the
cycle error. Declaring them inside the thunk instead resets them on every
force, silently defeating both memoization and cycle detection.

The transform builds the partial applications in 'fromRGI'
(@runtimeLazy(name)(thunk)@) and the force calls in 'makeForceCall'
(@lazyName(line)@). Keep this fixture's curried arity and the scope of
'state'/'val' in step with those sites. Adapted from the PureScript JS
backend's @$runtime_lazy@, a single 3-argument @(name, moduleName, init)@
function; the Lua port is curried and omits @moduleName@.
-}
runtimeLazy ∷ Statement
runtimeLazy =
  ForeignSourceStat
    [__i|
    local function #{Name.toText runtimeLazyName}(name)
      return function(init)
        local state = 0
        local val = nil
        return function()
          if state == 2 then
            return val
          else
            if state == 1 then
              return error(name .. " was needed before it finished initializing")
            else
              state = 1
              val = init()
              state = 2
              return val
            end
          end
        end
      end
    end
    |]

objectUpdateName ∷ Name
objectUpdateName = psluaName [name|object_update|]

objectUpdate ∷ Statement
objectUpdate =
  ForeignSourceStat
    [__i|
    local function #{Name.toText objectUpdateName}(o, patches)
      local o_copy = {}
      for k, v in pairs(o) do
        local patch_v = patches[k]
        if patch_v ~= nil then
          o_copy[k] = patch_v
        else
          o_copy[k] = v
        end
      end
      return o_copy
    end
    |]
