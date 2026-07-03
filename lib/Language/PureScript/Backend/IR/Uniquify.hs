{- | The entry pass of the IR pipeline (issue #139): give every local
binder a unique name within its top-level site and rewrite every local
reference to index 0, establishing the global-uniqueness condition
(GUC = @UniqueBinders@ + @IndicesZero@) that the rest of the pipeline
requires and preserves.

The traversal resolves (name, index) references according to
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
  , unIndex
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
first: a reference (name, index) resolves to the stack entry at the
index's position.
-}
type RenamesInScope = Map Name [Name]

uniquifyNamesInExpr ∷ Exp → Exp
uniquifyNamesInExpr e =
  evalState (go mempty e) (Set.singleton (Name runtimeLazyName))
 where
  go ∷ RenamesInScope → Exp → State (Set Name) Exp
  go scope = \case
    LiteralArray ann as →
      LiteralArray ann <$> traverse (go scope) as
    LiteralObject ann ps →
      LiteralObject ann <$> traverse (traverse (go scope)) ps
    ReflectCtor ann a →
      ReflectCtor ann <$> go scope a
    Eq ann a b →
      Eq ann <$> go scope a <*> go scope b
    DataArgumentByIndex ann index a →
      DataArgumentByIndex ann index <$> go scope a
    ArrayLength ann a →
      ArrayLength ann <$> go scope a
    ArrayIndex ann a index →
      ArrayIndex ann <$> go scope a <*> pure index
    ObjectProp ann a prop →
      ObjectProp ann <$> go scope a <*> pure prop
    ObjectUpdate ann a ps →
      ObjectUpdate ann <$> go scope a <*> traverse (traverse (go scope)) ps
    App ann a b →
      App ann <$> go scope a <*> go scope b
    IfThenElse ann i t f →
      IfThenElse ann <$> go scope i <*> go scope t <*> go scope f
    Abs ann param body →
      case param of
        ParamUnused _ann → Abs ann param <$> go scope body
        ParamNamed paramAnn name → do
          (name', scope') ← bindName scope name
          Abs ann (ParamNamed paramAnn name') <$> go scope' body
    Ref ann qname index →
      pure case qname of
        Local lname
          | Just renames ← Map.lookup lname scope
          , -- Index by the De Bruijn 'Natural' directly. 'genericDrop'
            -- takes it with no narrowing 'Int' conversion, and an index
            -- past the end yields '[]', so 'viaNonEmpty head' gives
            -- 'Nothing' (no rename: the reference is free).
            Just rename ←
              viaNonEmpty head (genericDrop (unIndex index) renames) →
              Ref ann (Local rename) 0
        _ → Ref ann qname index
    Let ann binds body → do
      (scope', binds') ← foldlM withGrouping (scope, []) (toList binds)
      Let ann (NE.fromList (reverse binds')) <$> go scope' body
    -- Terminals:
    terminal@LiteralInt {} → pure terminal
    terminal@LiteralFloat {} → pure terminal
    terminal@LiteralString {} → pure terminal
    terminal@LiteralChar {} → pure terminal
    terminal@LiteralBool {} → pure terminal
    terminal@Ctor {} → pure terminal
    terminal@Exception {} → pure terminal
    -- The names of a foreign import are the export keys of the foreign
    -- source file, not binders — they must not be renamed.
    terminal@ForeignImport {} → pure terminal

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
