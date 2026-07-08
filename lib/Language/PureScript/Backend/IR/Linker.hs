{-# LANGUAGE PartialTypeSignatures #-}

module Language.PureScript.Backend.IR.Linker where

import Control.Lens (over)
import Data.Graph (graphFromEdges', reverseTopSort)
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Inliner qualified as Inline
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
    name @foreign@ (@QName moduleName (Name "foreign")@). It carries the module
    name, the source path, and the list of foreign names.
  * One 'ObjectProp' per foreign name, bound to @QName moduleName name@, that
    reads that name as a field off the @foreign@ import. It carries the name's
    @inline@ pragma annotation when one is declared, and defaults to
    'Inline.Always'.

'Language.PureScript.Backend.IR.DCE' depends on exactly these shapes: it splits
the foreigns into 'ForeignImport's and 'ObjectProp's by pattern, and when it
keeps a 'ForeignImport' it prunes the carried name list to the reachable names.
Change either shape here and the DCE patterns silently stop matching.
-}
foreignBindings ∷ Module → [(QName, Exp)]
foreignBindings Module {moduleName, modulePath, moduleForeigns} =
  foreignModuleBinding <> foreignNamesBindings
 where
  foreignName = Name "foreign"

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
          (ann <|> Just Inline.Always)
          (refImported moduleName foreignName)
          (PropName (nameToText name))
      )

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
