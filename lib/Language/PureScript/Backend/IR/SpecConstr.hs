{- | Call-pattern specialization for recursive bindings (issue #208).

A recursive function that carries a constructor accumulator allocates
the box on every iteration only to take it apart at the top of the next
one:

> go acc = case acc of
>   Tuple s i
>     | i >= n → acc
>     | otherwise → go (Tuple (s + i) (i + 1))

This is GHC's SpecConstr discipline transplanted to the IR: for a
recursive-group member whose body scrutinizes a parameter and whose
call sites within the group pass a known constructor at that position,
mint a specialized copy taking the constructor's fields as separate
parameters, and rewrite the qualifying call sites — the group's own and
everyone else's — to call it directly. The original binding stays
behind as the boxed entry point for callers that do not know the
constructor.

== The specialization

For a member @f = AbsN [p₁ … pₙ] body@ and a call pattern ⟨k, K\/m⟩
(sites pass constructor @K@ of @m@ fields at position @k@):

  * the specialized copy is
    @f$sc\<k+1\>\<K\> = AbsN [p₁ … pₖ₋₁, f₁ … fₘ, pₖ₊₁ … pₙ] body′@,
    where @body′@ is a binder-freshened copy of @body@ with every read
    of @pₖ@ replaced by the rebox @K f₁ … fₘ@;
  * a qualifying site @f(a₁, …, K b₁ … bₘ, …, aₙ)@ becomes
    @f$sc…(a₁, …, b₁ … bₘ, …, aₙ)@.

No folding happens here: the reboxes pasted at constructor-eliminating
reads ('ReflectCtor', 'DataArgumentByIndex') meet the
case-of-known-constructor folds (issue #177) in the surrounding
fixpoint's optimize pass, which collapse them to the tag string and the
field references — the specialized loop then carries raw values. A
rebox at a whole-value read (an exit path returning the accumulator)
survives as a real allocation, but it runs only where the box genuinely
escapes, not per iteration.

== Guards

  * Recursive bindings only: the non-recursive case is ordinary
    inlining plus the constructor folds.
  * The scrutiny requirement: position @k@ qualifies only when the
    body eliminates the parameter through a tag or field read —
    specializing an unscrutinized box would only move the allocation.
  * The pattern requirement: the constructor must appear at a call
    site within the group itself, so the recursion is what carries the
    box. Once minted, every qualifying site in the module is rewritten
    — an entry call @go (Tuple 0 0)@ included, which is what lets DCE
    drop the boxed entry when nobody boxed is left calling it.
  * 'specConstrLimit' caps the specializations minted per binding (the
    @-fspec-constr-count@ analogue), counted over the group's existing
    @$sc@ siblings, so iterated runs cannot mint without bound.
  * One run mints one layer instead of iterating to a fixpoint: a
    pattern exposed by a specialized body (a nested accumulator) is
    only visible after the surrounding fixpoint's optimize pass folds
    the previous layer's reboxes, so the enclosing
    specialize+dce fixpoint provides the bounded iteration and this
    pass reports 'Unmodified' as soon as no unhandled pattern remains.

== Names

Minted names are deterministic (the supply is drawn only inside
'freshenBinders'): the specialized binding is
@\<f\>$sc\<k+1\>\<CtorName\>@ — pattern-keyed, so a rerun that meets
the same pattern again finds the existing binding by name and rewrites
the new sites to it instead of minting a duplicate — and its field
parameters are @\<spec\>$f\<i\>@. @$@ cannot occur in a source
identifier and no other pass mints an @$sc@ group, so the schemes
cannot collide.
-}
module Language.PureScript.Backend.IR.SpecConstr
  ( specConstr
  , specConstrLimit
  ) where

import Control.Lens (cosmosOf, toListOf, transformMOf, transformOf)
import Control.Monad.Writer.CPS
  ( Writer
  , WriterT
  , runWriter
  , runWriterT
  , tell
  , writer
  )
import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Language.PureScript.Backend.IR.Inliner qualified as Inliner
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , Qualified (..)
  , nameToText
  , renderCtorName
  )
import Language.PureScript.Backend.IR.Query
  ( CtorShape (..)
  , resolveKnownCtorApp
  )
import Language.PureScript.Backend.IR.Supply (SupplyM)
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , WasRewritten
  , freshenBinders
  , getAnn
  , noAnn
  , refLocal
  , rewrittenIf
  , setAnn
  , subexpressions
  )

{- | The @-fspec-constr-count@ analogue: how many specializations one
binding may accumulate across all runs, counted over its existing
@$sc@ siblings.
-}
specConstrLimit ∷ Int
specConstrLimit = 3

{- | Specialize the recursive bindings of the module on the
known-constructor call patterns their groups carry, and rewrite every
qualifying call site to the specialized copies. The 'Set' argument is
the veto collected by the optimizer ('inline' pragmas declare intent
about the name's call shape as-is); vetoed bindings are left alone.
-}
specConstr ∷ Set QName → UberModule → SupplyM (UberModule, WasRewritten)
specConstr vetoed uber@UberModule {..} = do
  (bindings1, topSpecs) ←
    second (List.sortOn specPos . concat) . List.unzip
      <$> traverse processTopGrouping uberModuleBindings
  let topActives = activesOf topSpecs
  ((bindings2, exports2), changes) ← runWriterT do
    tell (Any (any (isJust . specRHS) topSpecs))
    bindings' ←
      traverse (traverse (traverse (processSite env topActives))) bindings1
    exports' ←
      traverse (traverse (processSite env topActives)) uberModuleExports
    pure (bindings', exports')
  let changed = getAny changes
  pure
    ( if changed
        then
          uber
            { uberModuleBindings = bindings2
            , uberModuleExports = exports2
            }
        else uber
    , rewrittenIf changed
    )
 where
  -- Constructor shapes at call sites resolve through the top-level
  -- environment, exactly as the optimizer's known-constructor folds do.
  env ∷ Map (Qualified Name) Exp
  env =
    Map.fromList
      [ (Imported modname name, expr)
      | Standalone (QName modname name, expr) ← uberModuleBindings
      ]

  topVeto ∷ Qualified Name → Exp → Bool
  topVeto ref rhs = case ref of
    Imported modname name → QName modname name `Set.member` vetoed
    Local _ → rootAnnVeto rhs

  -- Specialize one top-level recursive group: mint its specializations
  -- and splice each in front of the member it specializes. Call sites
  -- (its members' included) are rewritten by the later 'processSite'
  -- sweep, which visits every top-level right-hand side.
  processTopGrouping
    ∷ Grouping (QName, Exp) → SupplyM (Grouping (QName, Exp), [Spec])
  processTopGrouping = \case
    g@(Standalone _) → pure (g, [])
    RecursiveGroup members → do
      specs ←
        groupSpecs env topVeto $
          [ (Imported modname name, name, rhs)
          | (QName modname name, rhs) ← toList members
          ]
      let spliceMember (qname@(QName modname name), rhs) =
            [ (QName modname (specName s), specRhs)
            | s ← specs
            , specOriginRef s == Imported modname name
            , Just specRhs ← [specRHS s]
            ]
              <> [(qname, rhs)]
      pure
        ( RecursiveGroup (NE.fromList (spliceMember =<< toList members))
        , specs
        )

--------------------------------------------------------------------------------
-- Specializations of one recursive group --------------------------------------

{- | One call pattern's specialization: how call sites recognise it and,
when freshly minted this run, the binding to splice in.
-}
data Spec = Spec
  { specOriginRef ∷ Qualified Name
  -- ^ The group member being specialized, as call sites reference it
  , specName ∷ Name
  , specRef ∷ Qualified Name
  -- ^ How rewritten call sites reference the specialization
  , specArity ∷ Int
  -- ^ The origin's parameter count (matched sites are saturated)
  , specPos ∷ Int
  -- ^ 0-based position of the specialized parameter
  , specShape ∷ CtorShape
  , specFields ∷ Int
  -- ^ The constructor's field count
  , specRHS ∷ Maybe Exp
  {- ^ 'Just' for a fresh mint; 'Nothing' when an earlier run minted the
  binding already (new sites are still rewritten to it)
  -}
  }

{- | The specializations of one recursive group: for every call pattern
found in the group members' right-hand sides — a saturated call of a
scrutinizing member passing a known constructor at a scrutinized
position — either mint the specialized copy or, when a binding with the
pattern's name already exists in the group, re-register it for
site rewriting only.
-}
groupSpecs
  ∷ Map (Qualified Name) Exp
  -- ^ Environment resolving constructor references
  → (Qualified Name → Exp → Bool)
  -- ^ Veto: members this pass may not specialize
  → [(Qualified Name, Name, Exp)]
  -- ^ The group's members: site reference, name, right-hand side
  → SupplyM [Spec]
groupSpecs env veto members =
  snd <$> foldlM mintPattern (Map.empty, []) patterns
 where
  memberNames ∷ Set Name
  memberNames = Set.fromList [name | (_ref, name, _rhs) ← members]

  -- Members eligible for specialization: a manifest lambda, not
  -- vetoed, with at least one scrutinized named parameter.
  candidates
    ∷ Map (Qualified Name) (Name, NonEmpty (Parameter Ann), Exp, Set Int)
  candidates =
    Map.fromList
      [ (ref, (name, params, body, scrutinized))
      | (ref, name, rhs@(AbsN _ params body)) ← members
      , not (veto ref rhs)
      , let eliminated = eliminatedNames body
            scrutinized =
              Set.fromList
                [ k
                | (k, ParamNamed _ p) ← zip [0 ..] (toList params)
                , p `Set.member` eliminated
                ]
      , not (Set.null scrutinized)
      ]

  -- The call patterns the recursion carries: for each saturated
  -- group-internal call site of a candidate, the first scrutinized
  -- position holding a known constructor. Positions the specialization
  -- would leave parameterless are skipped ('AbsN' cannot bind zero
  -- parameters).
  patterns ∷ [(Qualified Name, Int, CtorShape, Int)]
  patterns =
    ordNub
      [ (ref, k, shape, length fields)
      | (_ref, _name, rhs) ← members
      , AppN _ (Ref _ ref) args ← toListOf (cosmosOf subexpressions) rhs
      , Just (_f, params, _body, scrutinized) ← [Map.lookup ref candidates]
      , length args == length params
      , (k, shape, fields) : _ ←
          [ [ (k, shape, fields)
            | k ← Set.toAscList scrutinized
            , Just arg ← [toList args !!? k]
            , Just (shape, fields) ← [resolveKnownCtorApp env arg]
            , length params - 1 + length fields >= 1
            ]
          ]
      ]

  -- How many specializations a member already accumulated in earlier
  -- runs: its @$sc@-prefixed siblings.
  existingSpecCount ∷ Name → Int
  existingSpecCount f =
    length
      [ ()
      | n ← Set.toList memberNames
      , (nameToText f <> "$sc") `Text.isPrefixOf` nameToText n
      ]

  mintPattern
    ∷ (Map Name Int, [Spec])
    → (Qualified Name, Int, CtorShape, Int)
    → SupplyM (Map Name Int, [Spec])
  mintPattern acc@(counts, specs) (ref, k, shape, fieldCount) =
    case Map.lookup ref candidates of
      Nothing → pure acc
      Just (f, params, body, _scrutinized) → do
        let sname = mkSpecName f k shape
            spec =
              Spec
                { specOriginRef = ref
                , specName = sname
                , specRef = case ref of
                    Imported modname _ → Imported modname sname
                    Local _ → Local sname
                , specArity = length params
                , specPos = k
                , specShape = shape
                , specFields = fieldCount
                , specRHS = Nothing
                }
        if sname `Set.member` memberNames
          then pure (counts, spec : specs)
          else do
            let used = Map.findWithDefault (existingSpecCount f) f counts
            if used >= specConstrLimit
              then pure acc
              else
                mintRHS params body k shape fieldCount sname <&> \case
                  Nothing → acc
                  Just rhs →
                    ( Map.insert f (used + 1) counts
                    , spec {specRHS = Just rhs} : specs
                    )

{- | Build the specialized right-hand side: a binder-freshened copy of
the member with the parameter at the pattern position replaced by the
constructor's fields, and every read of it in the body replaced by the
rebox — which the case-of-known-constructor folds then collapse at
every eliminating read.
-}
mintRHS
  ∷ NonEmpty (Parameter Ann)
  → Exp
  → Int
  → CtorShape
  → Int
  → Name
  → SupplyM (Maybe Exp)
mintRHS params body k shape fieldCount sname = do
  fresh ← freshenBinders (AbsN noAnn params body)
  pure case fresh of
    AbsN _ params' body'
      | (pre, ParamNamed _ pk : post) ← List.splitAt k (toList params')
      , Just newParams ← nonEmpty (pre <> fieldParams <> post) →
          let rebox =
                Ctor
                  noAnn
                  (ctorShapeType shape)
                  (ctorShapeModule shape)
                  (ctorShapeTyName shape)
                  (ctorShapeCtor shape)
                  (refLocal <$> fieldNames)
              subst = \case
                r@(Ref _ (Local n)) | n == pk → setAnn (getAnn r) rebox
                e → e
           in Just (AbsN noAnn newParams (transformOf subexpressions subst body'))
    _ → Nothing
 where
  fieldNames ∷ [Name]
  fieldNames =
    [ Name (nameToText sname <> "$f" <> Text.pack (show i))
    | i ← [1 .. fieldCount]
    ]
  fieldParams = ParamNamed noAnn <$> fieldNames

mkSpecName ∷ Name → Int → CtorShape → Name
mkSpecName f k shape =
  Name
    ( nameToText f
        <> "$sc"
        <> Text.pack (show (k + 1))
        <> renderCtorName (ctorShapeCtor shape)
    )

--------------------------------------------------------------------------------
-- Call-site rewriting ----------------------------------------------------------

{- | Registered specializations, keyed by how call sites reference the
member they specialize, tried in ascending parameter position.
-}
type Actives = Map (Qualified Name) [Spec]

activesOf ∷ [Spec] → Actives
activesOf specs =
  Map.fromListWith (flip (<>)) [(specOriginRef s, [s]) | s ← specs]

{- | Process one top-level right-hand side (or export): specialize the
local recursive groups it contains, splice the minted bindings into
their groups, and rewrite every qualifying call site — of the top-level
specializations and of this site's local ones alike. Local binder names
are unique per top-level site, so local candidates are collected and
rewritten independently per site (the discipline of
"Language.PureScript.Backend.IR.Uncurry").
-}
processSite
  ∷ Map (Qualified Name) Exp
  → Actives
  → Exp
  → WriterT Any SupplyM Exp
processSite env topActives expr = do
  localSpecs ←
    lift . fmap (List.sortOn specPos . concat) $
      traverse
        (groupSpecs env (const rootAnnVeto))
        [ [(Local name, name, rhs) | (_ann, name, rhs) ← toList localMembers]
        | Let _ groupings _ ← toListOf (cosmosOf subexpressions) expr
        , RecursiveGroup localMembers ← toList groupings
        ]
  let actives = Map.unionWith (<>) topActives (activesOf localSpecs)
      -- A freshly minted local binding is spliced above the bottom-up
      -- traversal's reach, so its own qualifying sites (the rewritten
      -- self-call that makes the specialized loop allocation-free) are
      -- rewritten here, before the splice.
      splices ∷ Map Name [(Name, Exp)]
      splices =
        Map.fromListWith
          (flip (<>))
          [ (name, [(specName s, fst (runWriter (rewriteSites env actives rhs)))])
          | s ← localSpecs
          , Local name ← [specOriginRef s]
          , Just rhs ← [specRHS s]
          ]
  tell (Any (any (isJust . specRHS) localSpecs))
  hoistWriter (spliceAndRewrite splices actives)
 where
  hoistWriter ∷ Writer Any a → WriterT Any SupplyM a
  hoistWriter = writer . runWriter

  spliceAndRewrite ∷ Map Name [(Name, Exp)] → Actives → Writer Any Exp
  spliceAndRewrite splices actives =
    flip (transformMOf subexpressions) expr \e → do
      e' ← rewriteSite env actives e
      case e' of
        Let ann groupings body
          | any needsSplice (toList groupings) →
              pure $
                Let ann (NE.fromList (spliceGrouping =<< toList groupings)) body
        other → pure other
   where
    needsSplice = \case
      RecursiveGroup localMembers →
        any
          (\(_ann, name, _rhs) → name `Map.member` splices)
          (toList localMembers)
      Standalone _ → False

    spliceGrouping = \case
      g@(Standalone _) → [g]
      RecursiveGroup localMembers →
        [RecursiveGroup (NE.fromList (spliceMember =<< toList localMembers))]

    spliceMember member@(_ann, name, _rhs) =
      [ (noAnn, sname, srhs)
      | (sname, srhs) ← Map.findWithDefault [] name splices
      ]
        <> [member]

-- | Rewrite every qualifying call site within the expression.
rewriteSites
  ∷ Map (Qualified Name) Exp → Actives → Exp → Writer Any Exp
rewriteSites env actives = transformMOf subexpressions (rewriteSite env actives)

{- | Rewrite one qualifying call site: a saturated call of a member with
a registered specialization, passing the pattern's constructor at the
pattern's position — the constructor node is unwrapped and its fields
passed directly.
-}
rewriteSite
  ∷ Map (Qualified Name) Exp → Actives → Exp → Writer Any Exp
rewriteSite env actives e = case e of
  AppN ann (Ref refAnn ref) args
    | Just specs ← Map.lookup ref actives
    , Just e' ← asum (matchSpec ann refAnn (toList args) <$> specs) →
        e' <$ tell (Any True)
  _ → pure e
 where
  matchSpec ∷ Ann → Ann → [Exp] → Spec → Maybe Exp
  matchSpec ann refAnn args Spec {..} = do
    guard (length args == specArity)
    arg ← args !!? specPos
    (shape, fields) ← resolveKnownCtorApp env arg
    guard (shape == specShape && length fields == specFields)
    newArgs ←
      nonEmpty (take specPos args <> fields <> drop (specPos + 1) args)
    pure (AppN ann (Ref refAnn specRef) newArgs)

--------------------------------------------------------------------------------
-- Helper Functions -------------------------------------------------------------

{- | Local names read through a constructor-eliminating position: a tag
or field read directly over the reference.
-}
eliminatedNames ∷ Exp → Set Name
eliminatedNames body =
  Set.fromList
    [ n
    | e ← toListOf (cosmosOf subexpressions) body
    , n ← case e of
        ReflectCtor _ (Ref _ (Local n)) → [n]
        DataArgumentByIndex _ _algTy _index (Ref _ (Local n)) → [n]
        _ → []
    ]

{- | Whether a right-hand side's root annotation vetoes specialization:
@inline never@ declares sharing intent for the binding as-is.
-}
rootAnnVeto ∷ Exp → Bool
rootAnnVeto rhs = getAnn rhs == Just Inliner.Never
