{- | Renumbering of the compiler-minted binders of an IR module.

The IR pipeline mints names by drawing an index from one monotone supply
shared by every pass ("Language.PureScript.Backend.IR.Supply"), so the
index a binder carries records how much supply the passes that ran before
it happened to consume. Rendering a module — the @.ir@ golden files, a
pass trace — therefore shows names that shift wholesale whenever an
unrelated pass starts consuming more or fewer names, burying the
structural change under renumbered lines.

'renumberUberModule' reassigns those indices in first-occurrence order,
one allocation per top-level site, making every minted name a function of
its own site's structure: a pass that consumes extra supply while
building one site cannot renumber another. See Note [Supply-drawn digit
runs] in "Language.PureScript.Backend.Renumber" for which digit runs
qualify — the positional suffixes of uncurrying (@f$w@, @f$p1@),
call-pattern specialization (@f$sc1Tuple@) and uniquification (@x0@) are
structural already and pass through.

The renaming is applied per site as a plain name-to-name map, with no
scope threading, which the GUC discipline (@UniqueBinders@) licenses:
within one site at most one binder carries any given name, so a local
reference belongs to the binder its name matches. The one local
reference a site may leave free is the runtime lazy factory (see
Note [The PSLUA_runtime_lazy coupling] in "Language.PureScript.Names"),
whose name holds no digit run and so is never an image of the
renumbering. Top-level names are drawn from source identifiers and
structural suffixes, never from the supply, so a site's renaming cannot
reach another site.
-}
module Language.PureScript.Backend.IR.Renumber (renumberUberModule) where

import Control.Lens (foldMapOf, over)
import Data.Map qualified as Map
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names (Name (..), Qualified (Local))
import Language.PureScript.Backend.IR.Types
  ( Grouping
  , Parameter (..)
  , RawExp (..)
  , bindingNames
  , listGrouping
  , paramName
  , subexpressions
  )
import Language.PureScript.Backend.Renumber
  ( Allocation
  , Delimiter (Delimiter)
  , noAllocation
  , renumberedText
  )

--------------------------------------------------------------------------------
-- Renumbering -----------------------------------------------------------------

{- | Renumber the minted binders of every top-level site — each binding,
foreign binding and export — independently of the others.
-}
renumberUberModule ∷ UberModule → UberModule
renumberUberModule uberModule =
  uberModule
    { uberModuleBindings =
        fmap renumberSite <<$>> uberModuleBindings uberModule
    , uberModuleForeigns = renumberSite <<$>> uberModuleForeigns uberModule
    , uberModuleExports = renumberSite <<$>> uberModuleExports uberModule
    }

-- | Renumber one site: allocate for its binders, then apply the renaming.
renumberSite ∷ RawExp ann → RawExp ann
renumberSite e = rename (siteRenaming (binders e)) e

{- | The renaming of a site's minted binder names, allocated in the order
'binders' visits them. Names carrying no supply-drawn index are absent,
which leaves them — and the references resolving to them — untouched.
-}
siteRenaming ∷ [Name] → Map Name Name
siteRenaming names =
  Map.fromList . catMaybes $
    evaluatingState noAllocation (traverse allocated names)
 where
  allocated ∷ Name → State Allocation (Maybe (Name, Name))
  allocated name =
    case renumberedText (Delimiter "$") noneReserved (nameToText name) of
      Nothing → pure Nothing
      Just mint → Just . (name,) . Name <$> mint

  -- Every image carries a @$@-delimited digit run, which no source
  -- identifier and no structural suffix can spell, so the allocation has
  -- no spelling to withhold.
  noneReserved ∷ Text → Bool
  noneReserved _spelling = False

-- | The site's binder names, in traversal order.
binders ∷ ∀ ann. RawExp ann → [Name]
binders = \case
  AbsN _ann params body → paramNames params <> binders body
  -- The RHS is outside the binders' scope (Note [Multi-value results]).
  LetValues _ann params rhs body →
    binders rhs <> paramNames params <> binders body
  Let _ann binds body →
    (bindingNames =<< toList binds)
      <> foldMap boundBinders (toList binds)
      <> binders body
  -- No other constructor binds a name ('ForeignImport' included: its
  -- name list holds the export keys of the foreign source file):
  other → foldMapOf subexpressions binders other
 where
  paramNames ∷ NonEmpty (Parameter ann) → [Name]
  paramNames = mapMaybe paramName . toList

  boundBinders ∷ Grouping (ann, Name, RawExp ann) → [Name]
  boundBinders = foldMap (\(_ann, _name, e) → binders e) . listGrouping

-- | Rewrite every binder and every local reference through the renaming.
rename ∷ ∀ ann. Map Name Name → RawExp ann → RawExp ann
rename renames = go
 where
  renamed ∷ Name → Name
  renamed name = Map.findWithDefault name name renames

  go ∷ RawExp ann → RawExp ann
  go = \case
    Ref ann (Local name) → Ref ann (Local (renamed name))
    AbsN ann params body → AbsN ann (renameParam <$> params) (go body)
    LetValues ann params rhs body →
      LetValues ann (renameParam <$> params) (go rhs) (go body)
    Let ann binds body → Let ann (fmap renameBound <$> binds) (go body)
    other → over subexpressions go other

  renameBound ∷ (ann, Name, RawExp ann) → (ann, Name, RawExp ann)
  renameBound (ann, name, e) = (ann, renamed name, go e)

  renameParam ∷ Parameter ann → Parameter ann
  renameParam = \case
    p@(ParamUnused _ann) → p
    ParamNamed ann name → ParamNamed ann (renamed name)
