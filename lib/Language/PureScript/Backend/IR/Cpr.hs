{- | Constructed Product Result: a worker/wrapper split on function
results (issue #206), the result-side twin of the arity split in
"Language.PureScript.Backend.IR.Uncurry".

A function whose every return path builds the same constructor allocates
a table per call even when every caller immediately deconstructs the
result — State-shaped code pays one Tuple per bind step. The split gives
such a function a worker returning the constructor's fields as Lua
multiple values, so a deconstructing caller binds the components
directly and the table never exists.

== The split

Every binding — top-level or 'Let'-bound — whose right-hand side is a
single n-ary lambda @AbsN [p₁…pₙ] body@ where every return path of
@body@ (through 'Let'\/'LetValues' bodies and both 'IfThenElse'
branches) ends in a saturated application of one fixed constructor
@C@ with k ≥ 1 fields (or in an 'Exception' — a path that never
returns is compatible with any result shape), and which has at least
one deconstructing call site (below), splits in place into

  * a /worker/ @f$r@ — the original parameters and body, with each
    constructor tail replaced by @Values [a₁…aₖ]@ (a multi-value
    return, Note [Multi-value results]), and

  * a /wrapper/ @f = AbsN [f$p…] (letValues f$v… = f$r(f$p…) in
    C f$v…)@ — the original name, reboxing the worker's results, for
    callers that consume the product as a first-class value.

Candidates are deliberately single 'AbsN' nodes — post-uncurry workers
and natural unary functions. A curried chain is not peeled: its
uncurried worker is the candidate, once the arity split has produced
it, so this pass is a second story on top of the uncurrying one.

== Deconstructing-site precondition and rewriting

The existing call-site machinery cannot cancel the wrapper's rebox on
its own: 'inlineSaturatedCall' unwinds only unary spines and refuses
n-ary lambda roots, so a wrapper of an n-ary worker would never be
pasted. The pass therefore rewrites the deconstructing sites itself. A
site is a 'Standalone' 'Let' binding @v = f a₁…aₙ@ — a saturated call
of a candidate — where @v@ is unreferenced in the sibling groupings and
read in the body only through constructor-eliminating reads (the exact
preconditions of 'propagateKnownCtorThroughLet', whose
'Language.PureScript.Backend.IR.Query.hasWholeValueRead' test is
shared). The binding's right-hand side becomes

> letValues $v… = f$r(a₁…aₙ) in C $v…

a direct worker call wrapped in a rebox constructed in place. In the
following optimize fixpoint, 'floatLetValuesFromLetRhs' surfaces the
rebox as a let-bound constructor and 'propagateKnownCtorThroughLet'
cancels it against the binder's reads, leaving the components bound
straight from the multi-value call.

A candidate with no such site is left alone: every caller consumes the
product whole, so a split would only add an unbox/rebox hop per call. A
result that flows away as a value keeps going through the wrapper
(which stays a plain reference — 'containsMultiValue' keeps the inliner
from pasting worker and wrapper bodies; a pasted wrapper would place its rebox in
expression position and lower to a per-call IIFE).

Reads reaching the call directly (@DataArgumentByIndex i (f a)@,
without the Let) are not rewritten in this version: in expression
position the rewritten shape would lower to an IIFE, trading the
removed table for a closure. Such sites keep calling the wrapper.

== Scoping of the candidate maps

As in the uncurrying pass: top-level candidates live in one module-wide
map (QNames are globally unique after
'Language.PureScript.Backend.IR.Linker.qualifyTopRefs'); local binder
names are unique only per top-level site (GUC), so local candidates are
collected, counted, and rewritten independently per site.

== Names

The worker name @\<f\>$r@ and the wrapper-internal @\<f\>$p\<i\>@ /
@\<f\>$v\<i\>@ are deterministic functions of the binding name, exactly
like the uncurrying pass's @$w@\/@$p@\/@$u@ schemes, and cannot collide
with source identifiers (no @$@ in PureScript identifiers), with
freshened binders (@\<name\>$\<digits\>@), or with any other minted
prefix. Site rebox binders are supply-fresh @$v\<n\>@ names — one mint
per rewritten site, following the @$field@ precedent of
'propagateKnownCtorThroughLet' (a deterministic scheme would need
per-site counters to stay unique).

The worker keeps the original binders (a separate top-level site — GUC
is per-site). The wrapper names all n parameters and passes them on;
the worker's own trailing 'ParamUnused' run is dropped by the Lua
backend, which discards the surplus arguments (the Note [Nullary
functions and Prim.undefined] convention). The worker is emitted to the
left of its wrapper (free-reference counting visits right to left).

== Excluded shapes

A constructor /function/ — the manifest lambda over a saturated 'Ctor'
of its own parameters that 'mkConstructor' emits, or the n-ary worker
the arity split derives from it — is not a candidate: its whole body is
the box, deconstructing sites are already served allocation-free by the
known-constructor folds ('resolveKnownCtorApp'), and the split would be
pure churn. Recursive candidates whose tails call themselves (or a
sibling) are declined in this version: every tail must be the fixed
constructor or an 'Exception'. Extending the tail language to
self-tail-calls (workers tail-calling workers, multiple values
propagating natively) is a documented follow-up.

== Rerun

A binding whose right-hand side is exactly the wrapper this pass builds
('reboxesTo') is an earlier run's output: it is not split again (that
would mint a duplicate @$r@), but its shape is re-registered, so
deconstructing sites that appeared between runs are still rewritten to
the existing worker. A fresh candidate whose @\<f\>$r@ name is
nonetheless taken is left alone entirely. Worker bodies fail the tail
test (their tails are 'Values'), so a rerun is otherwise a no-op and
the pass is idempotent.
-}
module Language.PureScript.Backend.IR.Cpr
  ( cprWorkerWrapper
  ) where

import Control.Lens (cosmosOf, toListOf, transformMOf)
import Control.Monad.Writer.CPS (WriterT, runWriterT, tell)
import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , Qualified (..)
  , nameToText
  )
import Language.PureScript.Backend.IR.Query
  ( CtorShape (..)
  , argsAreRefsTo
  , hasWholeValueRead
  , peelCtorParams
  , resolveKnownCtorApp
  )
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName)
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , WasRewritten
  , countFreeRef
  , getAnn
  , listGrouping
  , noAnn
  , paramName
  , refLocal
  , rewrittenIf
  , setAnn
  , subexpressions
  )

{- | The shape of a split candidate or an already-split wrapper, as the
site rewriter needs it: the call arity, the constructor, and its field
count.
-}
data Registered = Registered
  { regArity ∷ Int
  , regShape ∷ CtorShape
  , regFields ∷ Int
  }

{- | Split every qualifying binding into a multi-value worker and a
reboxing wrapper, and rewrite the deconstructing call sites to direct
worker calls behind an in-place rebox. The 'Set' argument is the same
veto the uncurrying pass takes: names whose call sites must stay
visible to name-keyed inline policies.
-}
cprWorkerWrapper
  ∷ Set QName → UberModule → SupplyM (UberModule, WasRewritten)
cprWorkerWrapper neverNames uber@UberModule {..} = do
  (processedBindings, bindingRewrites) ←
    fmap unzip . forM uberModuleBindings $ \grouping → do
      processed ← forM grouping \(qname, expr) → do
        (expr', rewritten) ← processSite expr
        pure ((qname, expr'), rewritten)
      pure (fst <$> processed, any snd (listGrouping processed))
  (processedExports, exportRewrites) ←
    fmap unzip . forM uberModuleExports $ \(name, expr) → do
      (expr', rewritten) ← processSite expr
      pure ((name, expr'), rewritten)
  let bindings' = splitTop =<< processedBindings
  pure
    ( uber
        { uberModuleBindings = bindings'
        , uberModuleExports = processedExports
        }
    , rewrittenIf
        (not (Map.null topSplit) || or bindingRewrites || or exportRewrites)
    )
 where
  -- The right-hand sides of every top-level binding: the environment
  -- 'resolveKnownCtorApp' resolves constructor references through (all
  -- constructor functions are top-level after linking).
  topEnv ∷ Map (Qualified Name) Exp
  topEnv =
    Map.fromList
      [ (Imported modname name, expr)
      | (QName modname name, expr) ← listGrouping =<< uberModuleBindings
      ]

  topLevelQNames ∷ Set QName
  topLevelQNames =
    Set.fromList (fst <$> (listGrouping =<< uberModuleBindings))

  -- Top-level classification: an already-split wrapper re-registers its
  -- shape (Left); a fresh candidate whose worker name is free may split
  -- (Right). See the module haddock's Rerun section.
  topClassified
    ∷ [ Either
          (Qualified Name, Registered)
          (Qualified Name, NonEmpty (Parameter Ann), Registered)
      ]
  topClassified =
    [ c
    | (QName modname name, expr) ← listGrouping =<< uberModuleBindings
    , QName modname name `Set.notMember` neverNames
    , let qualified = Imported modname name
    , c ← case classifyCandidate topEnv (cprWorkerOf qualified) expr of
        Just (Left reg) → [Left (qualified, reg)]
        Just (Right (params, shape, k)) →
          [ Right (qualified, params, Registered (length params) shape k)
          | QName modname (cprName name) `Set.notMember` topLevelQNames
          ]
        Nothing → []
    ]

  topDelegating ∷ Map (Qualified Name) Registered
  topDelegating = Map.fromList [(q, r) | Left (q, r) ← topClassified]

  topRegistrable ∷ Map (Qualified Name) Registered
  topRegistrable =
    Map.fromList [(q, r) | Right (q, _ps, r) ← topClassified]

  -- One deconstructing site anywhere in the module qualifies a
  -- top-level candidate; sites are every binding right-hand side and
  -- every export.
  siteExprs ∷ [Exp]
  siteExprs =
    (snd <$> (listGrouping =<< uberModuleBindings))
      <> (snd <$> uberModuleExports)

  topActivesAll ∷ Map (Qualified Name) Registered
  topActivesAll = Map.union topRegistrable topDelegating

  topCounts ∷ Map (Qualified Name) Int
  topCounts =
    Map.unionsWith (+) (censusIn topActivesAll <$> siteExprs)

  topSplit ∷ Map (Qualified Name) Registered
  topSplit =
    Map.filterWithKey
      (\q _ → Map.findWithDefault 0 q topCounts > 0)
      topRegistrable

  -- The registered map the sweeps rewrite against: split candidates
  -- and already-split wrappers.
  topActives ∷ Map (Qualified Name) Registered
  topActives = Map.union topSplit topDelegating

  -- Split the qualifying top-level bindings of the processed module,
  -- worker to the left of its wrapper (free-reference counting visits
  -- right to left, so a binding may only be referenced by material to
  -- its right).
  splitTop ∷ Grouping (QName, Exp) → [Grouping (QName, Exp)]
  splitTop = \case
    Standalone (qname, expr) →
      Standalone <$> splitMember (qname, expr)
    RecursiveGroup members →
      [RecursiveGroup (NE.fromList (splitMember =<< toList members))]
   where
    splitMember ∷ (QName, Exp) → [(QName, Exp)]
    splitMember (qname@(QName modname name), expr)
      | Just reg ← Map.lookup (Imported modname name) topSplit
      , AbsN _ params body ← expr =
          let workerRef = Imported modname (cprName name)
              (worker, wrapper) =
                workerAndWrapper
                  topEnv
                  (getAnn expr)
                  name
                  workerRef
                  params
                  body
                  reg
           in [(QName modname (cprName name), worker), (qname, wrapper)]
      | otherwise = [(qname, expr)]

  -- Process one top-level site: collect its local candidates, qualify
  -- them by their in-site deconstructing-site counts, then in one
  -- bottom-up sweep rewrite the qualifying sites and splice the
  -- splitting Let bindings into worker/wrapper pairs.
  processSite ∷ Exp → SupplyM (Exp, Bool)
  processSite expr = do
    (expr', rewritten) ←
      runWriterT (transformMOf subexpressions step expr)
    pure (expr', getAny rewritten || not (Map.null localSplit))
   where
    -- The site's Let binders, for the taken-name check: a local @$r@
    -- name can only have been minted by an earlier run of this pass,
    -- and it is always Let-bound.
    letBoundNames ∷ Set Name
    letBoundNames =
      Set.fromList
        [ name
        | Let _ groupings _ ← toListOf (cosmosOf subexpressions) expr
        , (_ann, name, _rhs) ← listGrouping =<< toList groupings
        ]

    localClassified
      ∷ [ Either
            (Name, Registered)
            (Name, Registered)
        ]
    localClassified =
      [ c
      | Let _ groupings _ ← toListOf (cosmosOf subexpressions) expr
      , (_ann, name, rhs) ← listGrouping =<< toList groupings
      , c ← case classifyCandidate topEnv (Local (cprName name)) rhs of
          Just (Left reg) → [Left (name, reg)]
          Just (Right (params, shape, k)) →
            [ Right (name, Registered (length params) shape k)
            | cprName name `Set.notMember` letBoundNames
            ]
          Nothing → []
      ]

    localDelegating ∷ Map Name Registered
    localDelegating = Map.fromList [(n, r) | Left (n, r) ← localClassified]

    localRegistrable ∷ Map Name Registered
    localRegistrable = Map.fromList [(n, r) | Right (n, r) ← localClassified]

    localCounts ∷ Map (Qualified Name) Int
    localCounts =
      censusIn
        (Map.mapKeys Local (Map.union localRegistrable localDelegating))
        expr

    localSplit ∷ Map Name Registered
    localSplit =
      Map.filterWithKey
        (\n _ → Map.findWithDefault 0 (Local n) localCounts > 0)
        localRegistrable

    actives ∷ Map (Qualified Name) Registered
    actives =
      Map.unions
        [ topActives
        , Map.mapKeys Local localSplit
        , Map.mapKeys Local localDelegating
        ]

    step ∷ Exp → WriterT Any SupplyM Exp
    step = \case
      e@(Let ann groupings body) → do
        let members = toList groupings
        results ← traverse (rewriteGrouping members body) members
        pure
          if all isUnchanged results
            then e
            else Let ann (NE.fromList (fromRewritten =<< results)) body
      e → pure e

    -- Per Let member, in one pass: a qualifying deconstructing site
    -- gets its right-hand side reboxed; a splitting local candidate is
    -- spliced into its worker/wrapper pair. The two cannot overlap (a
    -- right-hand side is a call or a lambda, not both).
    rewriteGrouping
      ∷ [Grouping (Ann, Name, Exp)]
      → Exp
      → Grouping (Ann, Name, Exp)
      → WriterT Any SupplyM RewrittenGrouping
    rewriteGrouping members body grouping = case grouping of
      Standalone (bAnn, v, rhs)
        | Just (q, reg, args) ← saturatedCall actives rhs
        , all
            ((== 0) . countFreeRefGrouping v)
            (filter (not . isGroupingOf v) members)
        , countFreeRef (Local v) body > 0
        , not
            ( hasWholeValueRead
                v
                (ctorShapeType (regShape reg))
                (fromIntegral (regFields reg))
                body
            ) → do
            tell (Any True)
            rebox ← lift (siteRebox q reg args)
            pure (Replaced [Standalone (bAnn, v, rebox)])
      Standalone (bAnn, v, rhs)
        | Just reg ← Map.lookup v localSplit
        , AbsN _ absParams absBody ← rhs →
            let (worker, wrapper) =
                  workerAndWrapper
                    topEnv
                    (getAnn rhs)
                    v
                    (Local (cprName v))
                    absParams
                    absBody
                    reg
             in pure
                  ( Replaced
                      [ Standalone (noAnn, cprName v, worker)
                      , Standalone (bAnn, v, wrapper)
                      ]
                  )
      other → pure (Unchanged other)

  -- Build the in-place rebox a rewritten site binds: a direct worker
  -- call, its results bound to supply-fresh names, reboxed with the
  -- candidate's constructor. The following fixpoint cancels the box
  -- against the site's eliminating reads.
  siteRebox ∷ Qualified Name → Registered → NonEmpty Exp → SupplyM Exp
  siteRebox q Registered {regShape = CtorShape {..}, regFields} args = do
    vs ← replicateM regFields (freshName "$v")
    pure $
      LetValues
        noAnn
        (NE.fromList (ParamNamed noAnn <$> vs))
        (AppN noAnn (Ref noAnn (cprWorkerOf q)) args)
        ( Ctor
            noAnn
            ctorShapeType
            ctorShapeModule
            ctorShapeTyName
            ctorShapeCtor
            (refLocal <$> vs)
        )

{- | A Let member after the sweep: kept verbatim, or replaced by one or
two bindings (a reboxed site, or a spliced worker/wrapper pair). An
all-'Unchanged' Let is returned as the original node, keeping the
rebuild — and the fixpoint's convergence — precise.
-}
data RewrittenGrouping
  = Unchanged (Grouping (Ann, Name, Exp))
  | Replaced [Grouping (Ann, Name, Exp)]

isUnchanged ∷ RewrittenGrouping → Bool
isUnchanged = \case
  Unchanged _ → True
  Replaced _ → False

fromRewritten ∷ RewrittenGrouping → [Grouping (Ann, Name, Exp)]
fromRewritten = \case
  Unchanged g → [g]
  Replaced gs → gs

isGroupingOf ∷ Name → Grouping (Ann, Name, Exp) → Bool
isGroupingOf v = \case
  Standalone (_a, n, _e) → n == v
  RecursiveGroup {} → False

countFreeRefGrouping ∷ Name → Grouping (Ann, Name, Exp) → Natural
countFreeRefGrouping name grouping =
  sum [countFreeRef (Local name) e | (_ann, _n, e) ← listGrouping grouping]

--------------------------------------------------------------------------------
-- Candidate recognition -------------------------------------------------------

{- | Classify a binding right-hand side: 'Left' an already-split wrapper
(re-registered for site rewriting), 'Right' a fresh candidate with its
parameters and result shape, or 'Nothing'.
-}
classifyCandidate
  ∷ Map (Qualified Name) Exp
  → Qualified Name
  -- ^ The name the candidate's worker would have
  → Exp
  → Maybe (Either Registered (NonEmpty (Parameter Ann), CtorShape, Int))
classifyCandidate env workerRef = \case
  rhs@(AbsN _ params body)
    | Just reg ← reboxesTo workerRef params body →
        Just (Left reg)
    | Just (shape, k) ← cprTails env body
    , k >= 1
    , not (isCtorFunctionShape rhs) →
        Just (Right (params, shape, k))
  _ → Nothing

{- | The one fixed constructor every return path of the body ends in,
and its field count. Tails propagate through 'Let'\/'LetValues' bodies
and both 'IfThenElse' branches; an 'Exception' leaf is compatible with
any shape (that path never returns); any other leaf disqualifies —
including 'Values', so an already-built worker is never a candidate.
Requires at least one constructor leaf.
-}
cprTails ∷ Map (Qualified Name) Exp → Exp → Maybe (CtorShape, Int)
cprTails env body = do
  TailCtor shape k ← go body
  pure (shape, k)
 where
  go ∷ Exp → Maybe TailShape
  go = \case
    Let _ _ b → go b
    LetValues _ _ _ b → go b
    IfThenElse _ _cond th el → do
      t ← go th
      e ← go el
      combine t e
    Exception _ _ → Just TailBottom
    leaf
      | Just (shape, args) ← resolveKnownCtorApp env leaf →
          Just (TailCtor shape (length args))
      | otherwise → Nothing

  combine ∷ TailShape → TailShape → Maybe TailShape
  combine TailBottom t = Just t
  combine t TailBottom = Just t
  combine (TailCtor s k) (TailCtor s' _k')
    | s == s' = Just (TailCtor s k)
    | otherwise = Nothing

data TailShape = TailCtor CtorShape Int | TailBottom

{- | The constructor-function shape 'mkConstructor' emits (or the n-ary
worker the arity split derives from it): a lambda whose whole body is
the saturated 'Ctor' of its own parameters, in order. Splitting it is
pure churn — see the module haddock's Excluded shapes.
-}
isCtorFunctionShape ∷ Exp → Bool
isCtorFunctionShape rhs = case peelCtorParams rhs of
  (names@(_ : _), Ctor _ _ _ _ _ args) → argsAreRefsTo names args
  _ → False

{- | Recognise the wrapper this pass itself built: the body is exactly
the multi-value delegate-and-rebox over the given worker reference.
Used by the rerun classification.
-}
reboxesTo
  ∷ Qualified Name → NonEmpty (Parameter Ann) → Exp → Maybe Registered
reboxesTo workerRef params = \case
  LetValues
    _
    binders
    (AppN _ (Ref _ ref) args)
    (Ctor _ algTy modname tyname ctorname ctorArgs)
      | ref == workerRef
      , Just paramNames ← traverse paramName (toList params)
      , argsAreRefsTo paramNames (toList args)
      , Just binderNames ← traverse paramName (toList binders)
      , argsAreRefsTo binderNames ctorArgs →
          Just
            Registered
              { regArity = length params
              , regShape = CtorShape algTy modname tyname ctorname
              , regFields = length binderNames
              }
  _ → Nothing

{- | Match a deconstructing site's call: a single 'AppN' of a registered
name at exactly its arity. Unary candidates are the singleton case; a
longer flattened look-through is never taken ('AppN' argument lists are
not spines, Note [n-ary application]).
-}
saturatedCall
  ∷ Map (Qualified Name) Registered
  → Exp
  → Maybe (Qualified Name, Registered, NonEmpty Exp)
saturatedCall actives = \case
  AppN _ (Ref _ q) args
    | Just reg ← Map.lookup q actives
    , regArity reg == length args →
        Just (q, reg, args)
  _ → Nothing

{- | Count the qualifying deconstructing sites of each registered name
within one expression. Absent keys have no sites. The predicate matches
the sweep's exactly, so a split happens iff a site is rewritten.
-}
censusIn
  ∷ Map (Qualified Name) Registered
  → Exp
  → Map (Qualified Name) Int
censusIn actives expr =
  Map.fromListWith
    (+)
    [ (q, 1)
    | Let _ groupings body ← toListOf (cosmosOf subexpressions) expr
    , let members = toList groupings
    , Standalone (_bAnn, v, rhs) ← members
    , countFreeRef (Local v) body > 0
    , all
        ((== 0) . countFreeRefGrouping v)
        (filter (not . isGroupingOf v) members)
    , Just (q, reg, _args) ← [saturatedCall actives rhs]
    , not
        ( hasWholeValueRead
            v
            (ctorShapeType (regShape reg))
            (fromIntegral (regFields reg))
            body
        )
    ]

--------------------------------------------------------------------------------
-- Worker and wrapper construction ---------------------------------------------

{- | Build the worker (the original lambda with its constructor tails
returning multiple values) and the wrapper (the rebox under the
original name). The wrapper takes over the original root annotation: an
@inline@ pragma stays attached to the name it was declared for.
-}
workerAndWrapper
  ∷ Map (Qualified Name) Exp
  -- ^ Environment for resolving the constructor tails
  → Ann
  -- ^ The original right-hand side's root annotation
  → Name
  -- ^ The binding's own name (the wrapper keeps it)
  → Qualified Name
  -- ^ How the wrapper and call sites reference the worker
  → NonEmpty (Parameter Ann)
  -- ^ The candidate's parameters
  → Exp
  -- ^ The candidate's body
  → Registered
  -- ^ The candidate's result shape
  → (Exp, Exp)
workerAndWrapper env rootAnn name workerRef params body reg =
  (worker, wrapper)
 where
  Registered {regShape = CtorShape {..}, regFields} = reg
  worker = AbsN noAnn params (replaceCtorTails env body)
  wrapper =
    setAnn rootAnn $
      AbsN
        noAnn
        (ParamNamed noAnn <$> wrapperParams)
        ( LetValues
            noAnn
            (ParamNamed noAnn <$> wrapperResults)
            (AppN noAnn (Ref noAnn workerRef) (refLocal <$> wrapperParams))
            ( Ctor
                noAnn
                ctorShapeType
                ctorShapeModule
                ctorShapeTyName
                ctorShapeCtor
                (toList (refLocal <$> wrapperResults))
            )
        )
  wrapperParams ∷ NonEmpty Name
  wrapperParams =
    NE.fromList
      [ Name (nameToText name <> "$p" <> Text.pack (show i))
      | i ← [1 .. length params]
      ]
  wrapperResults ∷ NonEmpty Name
  wrapperResults =
    NE.fromList
      [ Name (nameToText name <> "$v" <> Text.pack (show i))
      | i ← [1 .. regFields]
      ]

{- | Replace each constructor tail with the multi-value return of its
fields. Mirrors the tail walk of 'cprTails' exactly; 'Exception' leaves
stay as they are.
-}
replaceCtorTails ∷ Map (Qualified Name) Exp → Exp → Exp
replaceCtorTails env = go
 where
  go = \case
    Let a bs b → Let a bs (go b)
    LetValues a ps rhs b → LetValues a ps rhs (go b)
    IfThenElse a c th el → IfThenElse a c (go th) (go el)
    leaf
      | Just (_shape, args@(_ : _)) ← resolveKnownCtorApp env leaf →
          Values (getAnn leaf) (NE.fromList args)
      | otherwise → leaf

--------------------------------------------------------------------------------
-- Names -----------------------------------------------------------------------

cprName ∷ Name → Name
cprName name = Name (nameToText name <> "$r")

cprWorkerOf ∷ Qualified Name → Qualified Name
cprWorkerOf = \case
  Imported modname name → Imported modname (cprName name)
  Local name → Local (cprName name)
