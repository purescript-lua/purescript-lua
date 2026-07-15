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
  | {- | A literal lambda applied, in a single call, to a number of
    arguments different from the number of parameters it binds
    ('WellApplied'). A lambda compiles to a Lua function of exactly its
    parameter count (Note [n-ary abstraction]), so surplus arguments are
    silently dropped and missing ones read as nil instead of currying.
    Carries the lambda's parameter count and the offending call's
    argument count.
    -}
    LambdaArityMismatch Site Natural Natural
  | {- | An 'AbsN' or 'LetValues' parameter list with a 'ParamUnused' in
    non-trailing position ('WellApplied'). The Lua backend drops unused
    parameters/binders, which is arity-preserving only for a trailing
    run (Note [n-ary abstraction], Note [Multi-value results]).
    -}
    NonTrailingUnusedParam Site
  | {- | An 'AppN' whose head is a 'Ctor' node ('WellApplied'). A
    constructor value is a table, never a function (see Note [Constructor
    applications are saturated]), so applying it would emit a call on a
    table. Reported as a single violation per site, like 'RefToDiscard'.
    -}
    CtorApplied Site
  | {- | A 'Values' node outside a multi-value slot ('WellApplied').
    Anywhere but a multi-value tail position Lua adjusts the value list
    to a single value — silent truncation of the remaining results (see
    Note [Multi-value results]). Reported as a single violation per
    site, like 'RefToDiscard'.
    -}
    ValuesOutsideTail Site
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

{- | Check the @WellApplied@ invariant — the well-formedness conditions
of the n-ary nodes (Note [n-ary abstraction]):

  * every 'AppN' with a literal lambda head passes exactly as many
    arguments as the lambda binds parameters — anything else silently
    drops arguments or nil-fills parameters instead of currying;

  * every 'AbsN' and every 'LetValues' keeps its 'ParamUnused'
    parameters in a trailing run, so the Lua backend can drop them
    without shifting the rest;

  * no 'AppN' head is a 'Ctor' — a constructor value is a table, not a
    function (see Note [Constructor applications are saturated]);

  * every 'Values' sits in a multi-value slot (Note [Multi-value
    results]) — anywhere else Lua silently truncates it to one value.

An empty result means the module holds the invariant.
-}
lintWellApplied ∷ UberModule → [Violation]
lintWellApplied = overSites \site e →
  (uncurry (LambdaArityMismatch site) <$> lambdaArityMismatches e)
    <> [NonTrailingUnusedParam site | hasNonTrailingUnusedParam e]
    <> [CtorApplied site | hasAppliedCtor e]
    <> [ValuesOutsideTail site | hasMisplacedValues e]

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
    AbsN _ params body →
      go (foldl' (\sc p → bindName (paramName p) sc) scope (toList params)) body
    -- The binders scope over the body only; the RHS sees the enclosing
    -- scope (Note [Multi-value results]).
    LetValues _ params rhs body →
      go scope rhs
        <> go
          (foldl' (\sc p → bindName (paramName p) sc) scope (toList params))
          body
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
    AbsN _ params _ → mapMaybe paramName (toList params)
    LetValues _ params _ _ → mapMaybe paramName (toList params)
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

{- | The (parameter count, argument count) of every 'AppN' that applies a
literal lambda to a number of arguments different from its parameter
count. Each such node is a miscompile: the lambda is a Lua function of
exactly its parameter count, so surplus arguments are dropped and
missing parameters read as nil.
-}
lambdaArityMismatches ∷ Exp → [(Natural, Natural)]
lambdaArityMismatches e =
  [ (fromIntegral (length params), fromIntegral (length args))
  | AppN _ (AbsN _ params _) args ← toListOf (cosmosOf subexpressions) e
  , length args /= length params
  ]

{- | Whether any 'AppN' of the expression applies a 'Ctor' head. A
constructor value is a table, never a function, so this would emit a call
on a table. Reported as a single violation per site, like 'RefToDiscard'.
-}
hasAppliedCtor ∷ Exp → Bool
hasAppliedCtor e =
  or
    [ True
    | AppN _ (Ctor {}) _ ← toListOf (cosmosOf subexpressions) e
    ]

{- | Whether any 'AbsN' or 'LetValues' of the expression binds a named
parameter after an unused one. Reported as a single violation per site,
like 'RefToDiscard'.
-}
hasNonTrailingUnusedParam ∷ Exp → Bool
hasNonTrailingUnusedParam e =
  or
    [ any (isJust . paramName) fromFirstUnused
    | node ← toListOf (cosmosOf subexpressions) e
    , params ← case node of
        AbsN _ ps _ → [toList ps]
        LetValues _ ps _ _ → [toList ps]
        _ → []
    , let (_named, fromFirstUnused) =
            break (isNothing . paramName) params
    ]

{- | Whether a 'Values' node occurs outside a multi-value slot — see
Note [Multi-value results] for the slot discipline this walk encodes:
an 'AbsN' body and a 'LetValues' RHS open a multi-value slot, 'Let' and
'LetValues' bodies and 'IfThenElse' branches (not the condition)
propagate it, and every other child position is single-valued. Reported
as a single violation per site, like 'RefToDiscard'.
-}
hasMisplacedValues ∷ Exp → Bool
hasMisplacedValues = go False
 where
  go ∷ Bool → Exp → Bool
  go multi = \case
    Values _ es → not multi || any (go False) (toList es)
    AbsN _ _params body → go True body
    LetValues _ _params rhs body → go True rhs || go multi body
    Let _ binds body →
      any (\(_ann, _nm, rhs) → go False rhs) (foldMap toList binds)
        || go multi body
    IfThenElse _ cond th el →
      go False cond || go multi th || go multi el
    other → any (go False) (toListOf subexpressions other)
