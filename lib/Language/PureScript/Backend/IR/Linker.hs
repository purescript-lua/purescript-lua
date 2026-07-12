{-# LANGUAGE PartialTypeSignatures #-}

module Language.PureScript.Backend.IR.Linker where

import Control.Lens (over)
import Data.Graph (graphFromEdges', reverseTopSort)
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , PropName (PropName)
  , QName (QName)
  , Qualified (Imported, Local)
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Binding
  , Exp
  , Grouping (..)
  , Module (..)
  , Parameter (ParamNamed, ParamUnused)
  , RawExp (..)
  , bindingNames
  , noAnn
  , refImported
  , subexpressions
  )

data LinkMode
  = LinkAsApplication ModuleName Name
  | LinkAsModule ModuleName
  deriving stock (Show)

data UberModule = UberModule
  { uberModuleBindings ∷ [Grouping (QName, Exp)]
  , uberModuleForeigns ∷ [(QName, Exp)]
  , uberModuleExports ∷ [(Name, Exp)]
  }
  deriving stock (Show, Eq)

makeUberModule ∷ LinkMode → [Module] → UberModule
makeUberModule linkMode (topoSorted → modules) =
  UberModule
    { uberModuleForeigns = foreignBindings =<< modules
    , uberModuleBindings = qualifiedModuleBindings =<< modules
    , uberModuleExports =
        case linkMode of
          LinkAsApplication moduleName name →
            [(name, refImported moduleName name)]
          LinkAsModule modname →
            [ (exportedName, refImported moduleName exportedName)
            | Module {moduleName, moduleExports} ← modules
            , moduleName == modname
            , exportedName ← moduleExports
            ]
    }

{- Note [Foreign bindings structure emitted by the Linker]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'foreignBindings' lowers a module's FFI into a fixed pair of expression shapes
that downstream passes pattern-match by structure, so the producer here and the
consumers must agree.

  * One 'ForeignImport' per module that has any foreigns, bound to the special
    name @foreign@ (@QName moduleName 'foreignName'@). It carries the module
    name, the source path, and the list of foreign names.
  * One 'ObjectProp' per foreign name, bound to @QName moduleName name@, that
    reads that name as a field off the @foreign@ import. It carries the name's
    @inline@ pragma annotation when one is declared and no annotation
    otherwise, leaving the dissolve-or-share decision to the optimizer's use
    count (see Note [Inline annotations and inlining heuristics]).

'Language.PureScript.Backend.IR.DCE' depends on exactly these shapes: it splits
the foreigns into 'ForeignImport's and 'ObjectProp's by pattern, and when it
keeps a 'ForeignImport' it prunes the carried name list to the reachable names.
'Language.PureScript.Backend.IR.Optimizer.shareForeignAccessors' recognises
dissolved copies of the accessor shape via 'foreignAccessorQName'. Change
either shape here and those patterns silently stop matching.
-}
foreignBindings ∷ Module → [(QName, Exp)]
foreignBindings Module {moduleName, modulePath, moduleForeigns} =
  foreignModuleBinding <> foreignNamesBindings
 where
  foreignModuleBinding ∷ [(QName, Exp)] =
    [ ( QName moduleName foreignName
      , ForeignImport noAnn moduleName modulePath moduleForeigns
      )
    | not (null moduleForeigns)
    ]

  -- See Note [Inline annotations and inlining heuristics]
  foreignNamesBindings ∷ [(QName, Exp)] =
    moduleForeigns <&> \(ann, name) →
      ( QName moduleName name
      , ObjectProp
          ann
          (refImported moduleName foreignName)
          (PropName (nameToText name))
      )

{- | The special name a module's 'ForeignImport' table is bound to
(Note [Foreign bindings structure emitted by the Linker]). @foreign@ is a
PureScript keyword, so no user-defined top-level binding can collide with it.
-}
foreignName ∷ Name
foreignName = Name "foreign"

{- | Recognise the accessor shape 'foreignBindings' emits — a field read off a
module's @foreign@ import — and recover the 'QName' the accessor was bound
to. Total on any expression: only the linker builds references to
'foreignName', and the property name round-trips through 'nameToText' (see
Note [Foreign bindings structure emitted by the Linker]).
-}
foreignAccessorQName ∷ RawExp ann → Maybe QName
foreignAccessorQName = \case
  ObjectProp _ann (Ref _refAnn (Imported modname name)) (PropName prop)
    | name == foreignName → Just (QName modname (Name prop))
  _ → Nothing

qualifiedModuleBindings ∷ Module → [Grouping (QName, Exp)]
qualifiedModuleBindings Module {moduleName, moduleBindings, moduleForeigns} =
  moduleBindings <&> \case
    Standalone binding → Standalone $ qualifyBinding binding
    RecursiveGroup bindings → RecursiveGroup $ qualifyBinding <$> bindings
 where
  qualifyBinding ∷ (Ann, Name, Exp) → (QName, Exp)
  qualifyBinding (_ann, name, expr) =
    (QName moduleName name, qualifyTopRefs moduleName topRefs expr)
   where
    topRefs ∷ Set Name =
      Set.fromList $
        (moduleBindings >>= bindingNames) <> fmap snd moduleForeigns

{- | Requalify references to the module's own top-level bindings from
'Local' to 'Imported'. A local reference resolves to the innermost
enclosing binder of its name (Note [Sequential scoping of Let
bindings]), so a top-level name shadowed by a λ parameter or a Let
binding leaves the visible set for the extent of that binder.
-}
qualifyTopRefs ∷ ModuleName → Set Name → Exp → Exp
qualifyTopRefs moduleName = go
 where
  go ∷ Set Name → Exp → Exp
  go topNames expression =
    case expression of
      Ref ann (Local refName)
        | isTopLevel refName →
            Ref ann (Imported moduleName refName)
      AbsN ann parameters body →
        AbsN ann parameters (go topNames' body)
       where
        topNames' ∷ Set Name =
          foldl' shadowParam topNames parameters
        shadowParam ∷ Set Name → Parameter ann → Set Name
        shadowParam names = \case
          ParamNamed _ann argName → Set.delete argName names
          ParamUnused _ann → names
      -- See Note [Sequential scoping of Let bindings]
      Let ann groupings body →
        Let ann groupings' (go topNamesAfterBinds body)
       where
        (topNamesAfterBinds, groupings') =
          mapAccumL qualifyGrouping topNames groupings
        qualifyGrouping ∷ Set Name → Binding → (Set Name, Binding)
        qualifyGrouping names grouping =
          case grouping of
            Standalone (a, name, expr) →
              ( Set.delete name names
              , Standalone (a, name, go names expr)
              )
            RecursiveGroup recBinds →
              ( names'
              , RecursiveGroup $
                  recBinds <&> \(a, name, expr) → (a, name, go names' expr)
              )
             where
              names' =
                foldr Set.delete names (bindingNames grouping)
      -- No other constructor binds names, so the top-name set passes
      -- through:
      _ → over subexpressions go' expression
   where
    isTopLevel ∷ Name → Bool
    isTopLevel name = Set.member name topNames

    go' ∷ Exp → Exp
    go' = go topNames

--------------------------------------------------------------------------------
-- Utils -----------------------------------------------------------------------

topoSorted ∷ [Module] → [Module]
topoSorted modules =
  reverseTopSort graph <&> (nodeFromVertex >>> \(m, _, _) → m)
 where
  (graph, nodeFromVertex) =
    graphFromEdges' $
      modules <&> \m@Module {..} →
        (m, moduleName, moduleImports)
