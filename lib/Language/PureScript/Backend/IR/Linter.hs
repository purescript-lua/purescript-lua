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
  , lintWellApplied
  , unboundLocals
  ) where

import Control.Lens (cosmosOf, toListOf)
import Data.Map qualified as Map
import Data.Set qualified as Set
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
  , RawExp (..)
  , bindingNames
  , listGrouping
  , paramName
  , subexpressions
  )
import Language.PureScript.Names (runtimeLazyName)

--------------------------------------------------------------------------------
-- Violations ------------------------------------------------------------------

-- | A broken IR invariant, located at a top-level site of the module.
data Violation
  = -- | A local reference with no matching binder ('WellScoped').
    UnboundLocal Site Name
  | -- | A local binder name bound more than once ('UniqueBinders').
    DuplicateBinder Site Name
  | {- | A reference to the discard binder @_@, which the 'UniqueBinders'
    check exempts on the assumption that it is never referenced
    (see 'discardName').
    -}
    RefToDiscard Site
  | {- | A literal lambda applied to more than one argument in a single
    call ('WellApplied'). A lambda compiles to a one-parameter Lua
    function (Note [n-ary application]), so every argument past the first
    would be silently dropped. The 'Natural' is the offending call's
    argument count.
    -}
    OverApplied Site Natural
  deriving stock (Eq, Show)

-- | The top-level entry of the module a violation was found in.
data Site
  = InBinding QName
  | InForeign QName
  | InExport Name
  deriving stock (Eq, Show)

--------------------------------------------------------------------------------
-- Linting ---------------------------------------------------------------------

{- | Check the @WellScoped@ invariant: every local reference has an
enclosing binder of its name. An empty result means the module holds
the invariant.
-}
lintWellScoped ∷ UberModule → [Violation]
lintWellScoped =
  overSites \site e → UnboundLocal site <$> unboundLocals e

{- | Check the @UniqueBinders@ invariant: within one top-level site no
local binder name is bound twice. The discard binder @_@ is exempt
(see 'discardName'), which is sound only while nothing references it —
so any reference to it is reported here too.
-}
lintUniqueBinders ∷ UberModule → [Violation]
lintUniqueBinders = overSites \site e →
  (DuplicateBinder site <$> duplicateBinders e)
    <> [RefToDiscard site | hasRefToDiscard e]

{- | Check the @WellApplied@ invariant: no literal lambda is applied to
more than one argument in a single call. A lambda compiles to a
one-parameter Lua function, so a multi-argument 'AppN' onto a lambda head
drops every argument past the first (Note [n-ary application]). A
well-formed multi-argument call always has a non-lambda head — a reference
to an n-ary foreign function. An empty result means the module holds the
invariant.
-}
lintWellApplied ∷ UberModule → [Violation]
lintWellApplied = overSites \site e →
  OverApplied site <$> overApplications e

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

{- | Local references with no enclosing binder of their name: unbound
locals, which the Lua backend rejects. An empty result means the
expression is well-scoped. See Note [Sequential scoping of Let
bindings] for the 'Let' binder bookkeeping.

The runtime lazy factory is the one deliberately free local reference:
the laziness transform emits @Local (Name runtimeLazyName)@ refs whose
definition is injected as a Lua fixture only at codegen (see
Note [The PSLUA_runtime_lazy coupling] in "Language.PureScript.Names"),
so the initial scope treats that name as bound by the runtime.
-}
unboundLocals ∷ Exp → [Name]
unboundLocals = go (Set.singleton (Name runtimeLazyName))
 where
  go ∷ Set Name → Exp → [Name]
  go scope = \case
    Ref _ (Local nm)
      | Set.member nm scope → []
      | otherwise → [nm]
    Abs _ param body → go (bindName (paramName param) scope) body
    Let _ binds body →
      let (bodyScope, errs) = foldl' letGrouping (scope, []) (toList binds)
       in errs <> go bodyScope body
    other → foldMap (go scope) (toListOf subexpressions other)
   where
    bindName ∷ Maybe Name → Set Name → Set Name
    bindName Nothing sc = sc
    bindName (Just nm) sc = Set.insert nm sc

    letGrouping
      ∷ (Set Name, [Name])
      → Grouping (a, Name, Exp)
      → (Set Name, [Name])
    letGrouping (sc, errs) = \case
      Standalone (_ann, nm, e) →
        ( Set.insert nm sc
        , errs <> go sc e
        )
      RecursiveGroup recBinds →
        ( sc'
        , errs <> foldMap (\(_ann, _nm, e) → go sc' e) recBinds
        )
       where
        sc' = foldr Set.insert sc names
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

{- | Whether the expression references the discard binder @_@. Reported
as a single violation per site: the occurrences are indistinguishable
('RefToDiscard' carries no location), so one entry says everything.
-}
hasRefToDiscard ∷ Exp → Bool
hasRefToDiscard e =
  or
    [ nm == discardName
    | Ref _ (Local nm) ← toListOf (cosmosOf subexpressions) e
    ]

{- | The argument count of every 'AppN' that applies a literal lambda to
more than one argument. Each such node is a miscompile: the lambda is a
one-parameter Lua function, so its surplus arguments are dropped.
-}
overApplications ∷ Exp → [Natural]
overApplications e =
  [ fromIntegral (length args)
  | AppN _ (Abs {}) args ← toListOf (cosmosOf subexpressions) e
  , length args > (1 ∷ Int)
  ]
