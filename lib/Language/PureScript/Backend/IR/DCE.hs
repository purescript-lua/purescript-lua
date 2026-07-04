module Language.PureScript.Backend.IR.DCE
  ( EntryPoint (..)
  , eliminateDeadCode
  ) where

import Control.Lens (foldMapOf, toListOf)
import Data.DList (DList)
import Data.DList qualified as DL
import Data.Graph (Graph, Vertex, graphFromEdges, reachable)
import Data.List.NonEmpty qualified as NE
import Data.Map qualified as Map
import Data.Set (member)
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (..)
  , QName (..)
  , Qualified (..)
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , WasRewritten (..)
  , getAnn
  , listGrouping
  , rewriteExpBottomUp
  , rewrittenIf
  , subexpressions
  )

data EntryPoint = EntryPoint ModuleName [Name]
  deriving stock (Show)

{- | Under GUC (@UniqueBinders@) a local reference resolves to its
binder by name alone.
-}
type Scope = Map (Qualified Name) Id

type Node = ((), Id, [Id])

{- | Drop the unreachable bindings of the module. The 'WasRewritten'
result (see 'Language.PureScript.Backend.IR.Pass.passRun') reports
precisely whether anything was dropped, blanked, or pruned — an
expression rewrite fired ('dceAnnotatedExp'), a top-level binding or
foreign was dropped, or a 'ForeignImport' name list was pruned.
-}
eliminateDeadCode ∷ UberModule → (UberModule, WasRewritten)
eliminateDeadCode uber@UberModule {..} =
  -- traceIt "annotatedForeigns" annotatedForeigns $
  --   traceIt "annotatedBindings" annotatedBindings $
  --     traceIt "annotatedExports" annotatedExports $
  --       traceIt "topLevelScope" topLevelScope $
  --         traceIt "adjacencyList" adjacencyList $
  --           traceIt "reachableIds" reachableIds $
  ( uber
      { uberModuleForeigns = preservedForeigns
      , uberModuleBindings = preservedBindings
      , uberModuleExports = preservedExports
      }
  , mconcat
      [ exprRewrites
      , rewrittenIf (length preservedForeigns /= length annotatedForeigns)
      , rewrittenIf
          (groupingMembers preservedBindings /= groupingMembers annotatedBindings)
      ]
  )
 where
  exprRewrites ∷ WasRewritten
  exprRewrites = foreignExprRewrites <> bindingExprRewrites <> exportExprRewrites

  groupingMembers ∷ [Grouping a] → Int
  groupingMembers = length . (listGrouping =<<)
  -- traceIt ∷ ∀ a b. Show a ⇒ String → a → b → b
  -- traceIt label it =
  --   trace ("\n\n" <> label <> ":\n" <> pp it <> "\n")
  --  where
  --   pp =
  --     toString
  --       . pShowOpt
  --         defaultOutputOptionsDarkBg
  --           { outputOptionsCompact = True
  --           }

  -- See Note [Foreign bindings structure emitted by the Linker]
  ( preservedForeigns ∷ [(QName, Exp)]
    , foreignExprRewrites ∷ WasRewritten
    ) = second fold $ unzip do
      (name, expr) ← annotatedForeigns
      guard $ nodeId expr `member` reachableIds
      pure case expr of
        ForeignImport (_id, ann) modname path names →
          let keptNames = [(a, n) | ((i, a), n) ← names, i `member` reachableIds]
           in ( (name, ForeignImport ann modname path keptNames)
              , rewrittenIf (length keptNames /= length names)
              )
        other → first (name,) (dceAnnotatedExp other)

  ( preservedBindings ∷ [Grouping (QName, Exp)]
    , bindingExprRewrites ∷ WasRewritten
    ) = second fold $ unzip do
      annotatedBindings >>= \case
        Standalone (qname, expr) → do
          guard $ nodeId expr `member` reachableIds
          let (e, rewritten) = dceAnnotatedExp expr
          [(Standalone (qname, e), rewritten)]
        RecursiveGroup recBinds →
          case NE.nonEmpty (preservedRecBinds (toList recBinds)) of
            Nothing → []
            Just pb → [(RecursiveGroup (fst <$> pb), foldMap snd pb)]
     where
      preservedRecBinds ∷ [(QName, AExp)] → [((QName, Exp), WasRewritten)]
      preservedRecBinds recBinds = do
        (qname, expr) ← recBinds
        guard $ nodeId expr `member` reachableIds
        pure (first (qname,) (dceAnnotatedExp expr))

  ( preservedExports ∷ [(Name, Exp)]
    , exportExprRewrites ∷ WasRewritten
    ) = second fold $ unzip do
      (name, annotatedExp) ← annotatedExports
      pure (first (name,) (dceAnnotatedExp annotatedExp))

  -- run these computations in the same monad
  -- so that we can share the state of the ID counter
  ( annotatedForeigns ∷ [(QName, AExp)]
    , annotatedBindings ∷ [Grouping (QName, AExp)]
    , annotatedExports ∷ [(Name, AExp)]
    ) = runAnnM do
      liftA3
        (,,)
        (traverse (traverse assignUniqueIds) uberModuleForeigns)
        (traverse (traverse (traverse assignUniqueIds)) uberModuleBindings)
        (traverse (traverse assignUniqueIds) uberModuleExports)

  -- See Note [Foreign bindings structure emitted by the Linker]
  annotatedForeignImports ∷ [(QName, AExp)] =
    [i | i@(_qname, ForeignImport {}) ← annotatedForeigns]

  annotatedForeignBindings ∷ [(QName, AExp)] =
    [b | b@(_qname, ObjectProp {}) ← annotatedForeigns]

  -- Bottom-up ('rewriteExpBottomUp'): a Let is decided only after its
  -- body has been fully processed, so when every binding is dropped and
  -- the node collapses to its body, a body that is itself a Let has
  -- already had its own dead bindings dropped — the Recurse-escape bug
  -- class (issue #149) cannot arise, and no rebuild cascade is needed.
  -- Both rules fire only when a binder is actually blanked or dropped
  -- (the 'RewriteRule' contract, issue #145), so the driver's
  -- 'WasRewritten' signal is precise.
  dceAnnotatedExp ∷ AExp → (Exp, WasRewritten)
  dceAnnotatedExp =
    first deannotateExp . rewriteExpBottomUp \case
      -- Under GUC a dead binder is unreferenced by definition, so
      -- blanking its name touches no reference elsewhere (the hazard
      -- behind issue #56). Requiring 'ParamNamed' keeps the rule
      -- precise: an already-blank parameter is left alone.
      Abs ann (ParamNamed pann@(paramId, _) _name) b
        | not (paramId `member` reachableIds) →
            Just (Abs ann (ParamUnused pann) b)
      Let ann binds body
        -- Under GUC dropping a dead binder touches no reference
        -- elsewhere in the Let (later grouping RHSs or the body): a
        -- dropped binder is unreferenced by definition, same as the
        -- Abs case above (pre-GUC this required 'unshift'ing the
        -- tail, issue #56).
        | let kept = preservedGroupings (toList binds)
        , members kept < members (toList binds) →
            Just case NE.nonEmpty kept of
              Nothing → body
              Just keptNE → Let ann keptNE body
      _ → Nothing
   where
    preservedGroupings
      ∷ [Grouping ((Id, Ann), Name, AExp)]
      → [Grouping ((Id, Ann), Name, AExp)]
    preservedGroupings = mapMaybe \case
      g@(Standalone ((nameId, _ann), _name, _expr)) →
        g <$ guard (nameId `member` reachableIds)
      RecursiveGroup recBinds →
        RecursiveGroup
          <$> NE.nonEmpty
            [ b
            | b@((nameId, _ann), _name, _expr) ← toList recBinds
            , nameId `member` reachableIds
            ]

    members ∷ [Grouping ((Id, Ann), Name, AExp)] → Int
    members = length . (listGrouping =<<)

  reachableIds ∷ Set Id =
    Set.fromList
      [ node
      | entryVertex ← entryVertices
      , reachableVertex ← reachable graph entryVertex
      , let (_node, node, _deps) = vertexToV reachableVertex
      ]

  entryVertices ∷ [Vertex] =
    [ vtx
    | (_name, expr) ← annotatedExports
    , vtx ← maybeToList (keyToVertex (nodeId expr))
    ]

  ------------------------------------------------------------------------------
  -- Building a graph of nodes -------------------------------------------------

  ( graph ∷ Graph
    , vertexToV ∷ Vertex → Node
    , keyToVertex ∷ Id → Maybe Vertex
    ) = graphFromEdges (toList adjacencyList)

  -- Crash if the adjacency list is not complete:
  -- every referenced node must be present in the list.
  -- assertAdjacencyListIsComplete
  --   ∷ HasCallStack
  --   ⇒ [Node]
  --   → [Node]
  -- assertAdjacencyListIsComplete al =
  --   if referencedNodes `isSubsetOf` nodes
  --     then al
  --     else
  --       error . unlines $
  --         [ "Incomplete adjacency list: "
  --         , toText (pShow al)
  --         , "Nodes: " <> toText (pShow nodes)
  --         , "Referenced nodes: " <> toText (pShow referencedNodes)
  --         ]
  --  where
  --   nodes = Set.fromList (al <&> \((), node, _) → node)
  --   referencedNodes = Set.fromList (al >>= \((), _, refs) → refs)

  mkNode ∷ Id → [Id] → Node
  mkNode = ((),,)

  adjacencyList ∷ DList Node =
    adjacencyListFromForeignImports
      <> adjacencyListFromForeignBindings
      <> adjacencyListFromExports
      <> adjacencyListFromBindings

  adjacencyListFromForeignImports ∷ DList Node = DL.fromList do
    annotatedForeignImports <&> \(_qname, expr) → mkNode (nodeId expr) []

  -- The functionality which builds adjacency list for foreign bindings
  -- depends on the particular sturcture emitted by the 'Linker' and therefore
  -- is not generic.
  adjacencyListFromForeignBindings ∷ DList Node =
    annotatedForeignBindings & foldMap \case
      ( QName bindingModule bindingName
        , ObjectProp (objPropId, _) (Ref (objRefId, _) _) _prop
        ) →
          DL.fromList do
            mkNode objPropId (objRefId : map fst foreignImportForBinding)
              : mkNode objRefId (map snd foreignImportForBinding)
              : [mkNode propId [] | (propId, _) ← foreignImportForBinding]
         where
          foreignImportForBinding ∷ [(Id, Id)] =
            [ (propId, importId)
            | ( QName importModule _foreign
                , ForeignImport (importId, _) _ _ propNames
                ) ←
                annotatedForeignImports
            , bindingModule == importModule
            , ((propId, _ann), propName) ← propNames
            , propName == bindingName
            ]
      _ → DL.empty

  adjacencyListFromExports ∷ DList Node =
    annotatedExports & foldMap \(_name, expr) →
      adjacencyListForExpr topLevelScope expr

  adjacencyListFromBindings ∷ DList Node =
    annotatedBindings & foldMap \case
      Standalone (_qname, expr) →
        adjacencyListForExpr topLevelScope expr
      RecursiveGroup recBinds →
        recBinds & foldMap \(_qname, expr) →
          adjacencyListForExpr topLevelScope expr

  topLevelScope ∷ Scope =
    Map.fromList (foreignsInScope <> bindingsInScope)
   where
    foreignsInScope = do
      (QName modname name, expr) ← annotatedForeigns
      pure (Imported modname name, nodeId expr)

    bindingsInScope = do
      (QName modname name, expr) ← listGrouping =<< annotatedBindings
      pure (Imported modname name, nodeId expr)

  adjacencyListForExpr ∷ Scope → AExp → DList Node
  adjacencyListForExpr scope expr =
    mkNode (nodeId expr) (expressionDependsOnIds scope expr)
      `DL.cons` case expr of
        Abs _ann param b →
          case param of
            ParamUnused _ann' → adjacencyListForExpr scope b
            ParamNamed (paramId, _ann) name →
              DL.cons
                (mkNode paramId [])
                (adjacencyListForExpr (addLocalToScope paramId name scope) b)
        Let _ann groupings body →
          adjacencyListForExpr bodyScope body <> groupingsAdjacency
         where
          -- The body resolves references against the scope threaded through
          -- the groupings left to right, so a name picks its *last*
          -- binding (see Note [Sequential scoping of Let bindings]).
          (bodyScope, groupingsAdjacency) =
            foldl' adjacencyListForGrouping (scope, mempty) groupings
        -- No other constructor binds names, so the scope passes through:
        other → foldMapOf subexpressions (adjacencyListForExpr scope) other
   where
    -- See Note [Sequential scoping of Let bindings]
    adjacencyListForGrouping
      ∷ (Scope, DList Node)
      → Grouping ((Id, Ann), Name, AExp)
      → (Scope, DList Node)
    adjacencyListForGrouping (groupingScope, adj) = \case
      Standalone binding@((nameId, _ann), _name, boundExpr) →
        ( updateScope binding groupingScope
        , DL.cons
            (mkNode nameId [nodeId boundExpr])
            (adjacencyListForExpr groupingScope boundExpr <> adj)
        )
      RecursiveGroup recBinds →
        ( scope'
        , recBinds & foldMap \((nameId, _ann), _name, boundExpr) →
            DL.cons
              (mkNode nameId [nodeId boundExpr])
              (adjacencyListForExpr scope' boundExpr <> adj)
        )
       where
        scope' = foldr updateScope groupingScope (toList recBinds)
     where
      updateScope ∷ ((Id, Ann), Name, AExp) → Scope → Scope
      updateScope ((nameId, _ann), name, _expr) = addLocalToScope nameId name

expressionDependsOnIds ∷ Scope → AExp → [Id]
expressionDependsOnIds exprScope = \case
  Ref _ann qname → maybeToList $ Map.lookup qname exprScope
  -- A Let node depends only on its body: the groupings are pulled in
  -- via the per-binder nodes built by 'adjacencyListForGrouping'.
  Let _ann _groupings body → [nodeId body]
  other → nodeId <$> toListOf subexpressions other

{- | Under GUC (@UniqueBinders@) no two live binders at one site share a
name, so a fresh local binder can never collide with one already in
scope: a plain insert suffices.
-}
addLocalToScope ∷ Id → Name → Scope → Scope
addLocalToScope nid name = Map.insert (Local name) nid

--------------------------------------------------------------------------------
-- Annotating expressions with IDs ---------------------------------------------

type Id = Natural

type AExp = RawExp (Id, Ann)

newtype AnnM a = AnnM {unAnnM ∷ State Id a}
  deriving newtype (Functor, Applicative, Monad)

nodeId ∷ AExp → Id
nodeId = fst . getAnn

nextId ∷ AnnM Id
nextId = AnnM (get >>= \i → i <$ put (i + 1))

runAnnM ∷ AnnM a → a
runAnnM = (`evalState` 0) . unAnnM

{- | Pair every annotation position of the expression — node, parameter,
Let-binding name, foreign-import name — with a fresh 'Id', via the
derived 'Traversable' of 'RawExp'.
-}
assignUniqueIds ∷ Exp → AnnM AExp
assignUniqueIds = traverse \ann → (,ann) <$> nextId

-- | Strip the 'Id's back off, via the derived 'Functor' of 'RawExp'.
deannotateExp ∷ AExp → Exp
deannotateExp = fmap snd
