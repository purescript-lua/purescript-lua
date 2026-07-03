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
  , lintWellScoped
  , lintUniqueBinders
  , lintIndicesZero
  , unboundLocals
  ) where

import Control.Lens (cosmosOf, toListOf)
import Data.Map qualified as Map
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName
  , Qualified (Local)
  , discardName
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , Index
  , RawExp (..)
  , bindingNames
  , listGrouping
  , paramName
  , subexpressions
  , unIndex
  )
import Language.PureScript.Names (runtimeLazyName)

--------------------------------------------------------------------------------
-- Violations ------------------------------------------------------------------

-- | A broken IR invariant, located at a top-level site of the module.
data Violation
  = -- | A local reference with no matching binder ('WellScoped').
    UnboundLocal Site Name Index
  | -- | A local binder name bound more than once ('UniqueBinders').
    DuplicateBinder Site Name
  | -- | A local reference with a nonzero De Bruijn index ('IndicesZero').
    NonZeroIndex Site Name Index
  | {- | A reference to the discard binder @_@, which the 'UniqueBinders'
    check exempts on the assumption that it is never referenced
    (see 'discardName').
    -}
    RefToDiscard Site
  deriving stock (Eq, Show)

-- | The top-level entry of the module a violation was found in.
data Site
  = InBinding QName
  | InForeign QName
  | InExport Name
  deriving stock (Eq, Show)

--------------------------------------------------------------------------------
-- Linting ---------------------------------------------------------------------

{- | Check the @WellScoped@ invariant: no local reference points past
every enclosing binder of its name. An empty result means the module
holds the invariant.
-}
lintWellScoped ∷ UberModule → [Violation]
lintWellScoped =
  overSites \site e → uncurry (UnboundLocal site) <$> unboundLocals e

{- | Check the @UniqueBinders@ invariant: within one top-level site no
local binder name is bound twice. The discard binder @_@ is exempt
(see 'discardName'), which is sound only while nothing references it —
so any reference to it is reported here too.
-}
lintUniqueBinders ∷ UberModule → [Violation]
lintUniqueBinders = overSites \site e →
  (DuplicateBinder site <$> duplicateBinders e)
    <> (RefToDiscard site <$ refsToDiscard e)

{- | Check the @IndicesZero@ invariant: every local reference has De
Bruijn index 0 (under @UniqueBinders@ a nonzero index cannot resolve).
-}
lintIndicesZero ∷ UberModule → [Violation]
lintIndicesZero =
  overSites \site e → uncurry (NonZeroIndex site) <$> nonZeroIndices e

{- | Run a per-site check over every top-level binding, foreign binding,
and export of the module.
-}
overSites ∷ (Site → Exp → [Violation]) → UberModule → [Violation]
overSites atSite UberModule {..} =
  foldMap
    (\(qname, e) → atSite (InBinding qname) e)
    (listGrouping =<< uberModuleBindings)
    <> foldMap (\(qname, e) → atSite (InForeign qname) e) uberModuleForeigns
    <> foldMap (\(name, e) → atSite (InExport name) e) uberModuleExports

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

{- | Local binder names bound more than once in the expression, in any
combination of positions (shadowing or parallel), 'discardName' exempt.
-}
duplicateBinders ∷ Exp → [Name]
duplicateBinders e =
  Map.keys . Map.filter (> (1 ∷ Natural)) $
    Map.fromListWith
      (+)
      [ (nm, 1)
      | node ← toListOf (cosmosOf subexpressions) e
      , nm ← binders node
      , nm /= discardName
      ]
 where
  binders ∷ Exp → [Name]
  binders = \case
    Abs _ param _ → maybeToList (paramName param)
    Let _ binds _ → bindingNames =<< toList binds
    _ → []

-- | References to the discard binder @_@ (one entry per occurrence).
refsToDiscard ∷ Exp → [()]
refsToDiscard e =
  [ ()
  | Ref _ (Local nm) _ ← toListOf (cosmosOf subexpressions) e
  , nm == discardName
  ]

-- | Local references with a nonzero De Bruijn index.
nonZeroIndices ∷ Exp → [(Name, Index)]
nonZeroIndices e =
  [ (nm, index)
  | Ref _ (Local nm) index ← toListOf (cosmosOf subexpressions) e
  , index /= 0
  ]
