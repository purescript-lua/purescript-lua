{- | The entry pass of the IR pipeline (issue #139): give every local
binder a unique name within its top-level site and repoint every local
reference at its renamed binder, establishing the global-uniqueness
condition (GUC = @UniqueBinders@) that the rest of the pipeline
requires and preserves.

The traversal resolves references according to
Note [Sequential scoping of Let bindings] while threading an
accumulator of every binder name used so far through the whole site
(not just the enclosing scope), so both shadowing /and parallel/
duplicates are renamed. Renaming is the digit-suffix scheme
(@x@ → @x0@, @x1@, …) with an internal counter — deliberately not the
shared pass supply, whose numbering feeds names minted downstream
(see "Language.PureScript.Backend.IR.Supply").

The only local reference this pass may leave free is the runtime lazy
factory (see Note [The PSLUA_runtime_lazy coupling] in
"Language.PureScript.Names"): its name seeds the used-names
accumulator, so no binder is ever renamed /to/ it, and a pathological
user binder of that name is renamed away from it.
-}
module Language.PureScript.Backend.IR.Uniquify
  ( uniquifyNames
  , uniquifyNamesInExpr
  ) where

import Control.Lens (traverseOf)
import Data.List.NonEmpty qualified as NE
import Data.Map qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , Qualified (Local)
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , subexpressions
  )
import Language.PureScript.Names (runtimeLazyName)

{- | Uniquify every top-level binding, foreign binding, and export.
Uniqueness is per-site: the used-names accumulator starts afresh for
each, so distinct sites may reuse the same binder names.
-}
uniquifyNames ∷ UberModule → UberModule
uniquifyNames uberModule =
  uberModule
    { uberModuleBindings =
        fmap uniquifyNamesInExpr <<$>> uberModuleBindings uberModule
    , uberModuleForeigns =
        uniquifyNamesInExpr <<$>> uberModuleForeigns uberModule
    , uberModuleExports =
        uniquifyNamesInExpr <<$>> uberModuleExports uberModule
    }

{- | The stack of renames for each source name in scope, innermost
first: a reference resolves to the innermost entry. The stack depth
feeds the suffix numbering in 'bindName' (a shadowing binder of @x@
starts probing at @x<depth>@), which keeps the minted names compact
and deterministic.
-}
type RenamesInScope = Map Name [Name]

uniquifyNamesInExpr ∷ Exp → Exp
uniquifyNamesInExpr e =
  evalState (go mempty e) (Set.singleton (Name runtimeLazyName))
 where
  go ∷ RenamesInScope → Exp → State (Set Name) Exp
  go scope = \case
    AbsN ann params body → do
      (scope', params') ← bindParams scope params
      AbsN ann params' <$> go scope' body
    -- The RHS sees the enclosing scope; the binders scope over the body
    -- only (Note [Multi-value results]).
    LetValues ann params rhs body → do
      rhs' ← go scope rhs
      (scope', params') ← bindParams scope params
      LetValues ann params' rhs' <$> go scope' body
    Ref ann qname →
      pure case qname of
        Local lname
          | Just (rename : _) ← Map.lookup lname scope →
              Ref ann (Local rename)
        _ → Ref ann qname
    Let ann binds body → do
      (scope', binds') ← foldlM withGrouping (scope, []) (toList binds)
      Let ann (NE.fromList (reverse binds')) <$> go scope' body
    -- No other constructor binds or references names, so the scope
    -- passes through ('ForeignImport' included: its name list holds the
    -- export keys of the foreign source file, not binders — they must
    -- not be renamed):
    other → traverseOf subexpressions (go scope) other

  bindParams
    ∷ RenamesInScope
    → NonEmpty (Parameter Ann)
    → State (Set Name) (RenamesInScope, NonEmpty (Parameter Ann))
  bindParams scope params = do
    (scope', reverse → params') ←
      foldlM
        ( \(sc, ps) param → case param of
            ParamUnused _ann → pure (sc, param : ps)
            ParamNamed paramAnn name → do
              (name', sc') ← bindName sc name
              pure (sc', ParamNamed paramAnn name' : ps)
        )
        (scope, [])
        (toList params)
    pure (scope', NE.fromList params')

  withGrouping
    ∷ (RenamesInScope, [Grouping (Ann, Name, Exp)])
    → Grouping (Ann, Name, Exp)
    → State (Set Name) (RenamesInScope, [Grouping (Ann, Name, Exp)])
  withGrouping (scope, bs) = \case
    Standalone (ann, name, expr) → do
      -- The RHS of a Standalone binding does not see its own binder
      -- (see Note [Sequential scoping of Let bindings]), so it is
      -- renamed under the pre-binding scope.
      expr' ← go scope expr
      (name', scope') ← bindName scope name
      pure (scope', Standalone (ann, name', expr') : bs)
    RecursiveGroup (toList → recGroup) → do
      -- Every member's RHS sees every member of its own group, itself
      -- included, so first bring all the members into scope, then
      -- rename the RHSs. Member order is preserved: it is the
      -- initialization order computed by the laziness transform.
      (groupScope, reverse → names') ←
        foldlM
          ( \(sc, names) (_ann, name, _expr) → do
              (name', sc') ← bindName sc name
              pure (sc', name' : names)
          )
          (scope, [])
          recGroup
      recGroup' ←
        zipWithM
          ( \name' (ann, _name, expr) →
              (ann,name',) <$> go groupScope expr
          )
          names'
          recGroup
      pure (groupScope, RecursiveGroup (NE.fromList recGroup') : bs)

  -- Bring a binder into scope: keep its name when it is the first use
  -- within the site, mint a fresh one otherwise, and record the result
  -- in the used-names accumulator either way.
  bindName ∷ RenamesInScope → Name → State (Set Name) (Name, RenamesInScope)
  bindName scope name = do
    used ← get
    let name'
          | Set.member name used =
              uniqueName used name (length (Map.findWithDefault [] name scope))
          | otherwise = name
    modify (Set.insert name')
    pure (name', Map.insertWith (<>) name [name'] scope)

  uniqueName ∷ Set Name → Name → Int → Name
  uniqueName usedNames n i =
    let nextName = Name (nameToText n <> show i)
     in if Set.member nextName usedNames
          then uniqueName usedNames n (i + 1)
          else nextName
