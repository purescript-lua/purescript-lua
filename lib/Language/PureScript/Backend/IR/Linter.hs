{- | Invariant checks over the IR, run at pass boundaries by the checked
pipeline runner (see 'Language.PureScript.Backend.IR.Pass') — in the test
suite always, in the CLI behind a debug flag. A violation names the exact
top-level site, turning a silent miscompile into a loud failure that
points at the offending pass.

The linter only checks 'Local' references: after
'Language.PureScript.Backend.IR.Linker.qualifyTopRefs' every top-level
cross-reference is 'Language.PureScript.Backend.IR.Names.Imported', which
this scope check deliberately ignores (mechanically checking those is
part of the globally-unique-names redesign, issue #139).
-}
module Language.PureScript.Backend.IR.Linter
  ( Violation (..)
  , Site (..)
  , lintUberModule
  , unboundLocals
  ) where

import Control.Lens (toListOf)
import Data.Map qualified as Map
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName
  , Qualified (Local)
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , Index
  , RawExp (..)
  , paramName
  , subexpressions
  , unIndex
  )
import Language.PureScript.Names (runtimeLazyName)

--------------------------------------------------------------------------------
-- Violations ------------------------------------------------------------------

-- | A broken IR invariant, located at a top-level site of the module.
data Violation = UnboundLocal Site Name Index
  deriving stock (Eq, Show)

-- | The top-level entry of the module a violation was found in.
data Site
  = InBinding QName
  | InForeign QName
  | InExport Name
  deriving stock (Eq, Show)

--------------------------------------------------------------------------------
-- Linting ---------------------------------------------------------------------

{- | Check every top-level binding, foreign binding, and export of the
module. An empty result means the module holds the linted invariants.
-}
lintUberModule ∷ UberModule → [Violation]
lintUberModule UberModule {..} =
  foldMap
    (\(qname, e) → atSite (InBinding qname) e)
    (listGrouping =<< uberModuleBindings)
    <> foldMap (\(qname, e) → atSite (InForeign qname) e) uberModuleForeigns
    <> foldMap (\(name, e) → atSite (InExport name) e) uberModuleExports
 where
  atSite ∷ Site → Exp → [Violation]
  atSite site e = uncurry (UnboundLocal site) <$> unboundLocals e

  listGrouping ∷ Grouping a → [a]
  listGrouping = \case
    Standalone a → [a]
    RecursiveGroup as → toList as

{- | Local references whose De Bruijn index points past every enclosing binder
of that name: unbound locals, which the Lua backend rejects (see
Note [Locals are uniquely named after renameShadowedNames]). An empty result
means the expression is well-scoped. The binder bookkeeping mirrors
'shift'/'unshift'; see Note [Sequential scoping of Let bindings] for 'Let'.

The runtime lazy factory is the one deliberately free local reference:
the laziness transform emits @Local (Name runtimeLazyName)@ refs whose
definition is injected as a Lua fixture only at codegen (see
Note [The PSLUA_runtime_lazy coupling] in "Language.PureScript.Names"),
so the initial scope treats that name as bound by the runtime.
-}
unboundLocals ∷ Exp → [(Name, Index)]
unboundLocals = go (Map.singleton (Name runtimeLazyName) 1)
 where
  go ∷ Map Name Natural → Exp → [(Name, Index)]
  go scope = \case
    Ref _ (Local nm) index
      | unIndex index < Map.findWithDefault 0 nm scope → []
      | otherwise → [(nm, index)]
    Abs _ param body → go (bindName (paramName param) scope) body
    Let _ binds body →
      let (bodyScope, errs) = foldl' letGrouping (scope, []) (toList binds)
       in errs <> go bodyScope body
    other → foldMap (go scope) (toListOf subexpressions other)
   where
    bindName ∷ Maybe Name → Map Name Natural → Map Name Natural
    bindName Nothing sc = sc
    bindName (Just nm) sc = Map.insertWith (+) nm 1 sc

    letGrouping
      ∷ (Map Name Natural, [(Name, Index)])
      → Grouping (a, Name, Exp)
      → (Map Name Natural, [(Name, Index)])
    letGrouping (sc, errs) = \case
      Standalone (_ann, nm, e) →
        ( Map.insertWith (+) nm 1 sc
        , errs <> go sc e
        )
      RecursiveGroup recBinds →
        ( sc'
        , errs <> foldMap (\(_ann, _nm, e) → go sc' e) recBinds
        )
       where
        sc' = foldr (\nm → Map.insertWith (+) nm 1) sc names
        names = (\(_ann, nm, _e) → nm) <$> toList recBinds
