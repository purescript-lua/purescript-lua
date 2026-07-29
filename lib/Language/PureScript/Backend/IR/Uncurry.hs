{- | Uncurry functions via a worker/wrapper split (issue #24).

A curried function compiles to nested closures: every application is a
separate Lua call allocating an intermediate closure — ~4.3x per
application under PUC Lua 5.1, and a trace-abort cliff under LuaJIT
(closure creation is NYI for the trace recorder, so every hot curried
loop gets blacklisted).

== The split

Every binding — top-level or 'Let'-bound — whose right-hand side is a
manifest chain of unary lambdas @λp₁.…λpₙ. body@ with n ≥ 2, and which
has at least one saturated call site in the program, splits in place
into

  * a /worker/ @f$w = AbsN [p₁…pₙ] body@ — one n-ary Lua function
    holding the original body and binders, and

  * a /wrapper/ @f = λf$p1.…λf$pn. f$w(f$p1, …, f$pn)@ — the original
    name, still curried, delegating to the worker.

Every saturated call site — a nested unary application spine of exactly
n arguments headed by a reference to the binding — is rewritten to the
direct worker call @f$w(a₁, …, aₙ)@; partial applications keep going
through the wrapper, and a reference passed as a value keeps denoting
the shared curried function. Semantics is unchanged by construction:
the worker body runs only on full saturation, so no work moves to
construction time and Note [Eta reduction is unsound] is not disturbed.

== Saturated-site precondition

A binding with no saturated site is left alone. Splitting it anyway
would leave a worker referenced only by its wrapper, and the revert
path through the use-once inliner plus n-ary beta reduction does not
exist everywhere: recursive-group members are never inlined, and a
local worker referenced from its sibling wrapper's right-hand side is
outside 'inlineLocalBindings'' reach (it only inlines into the 'Let'
body). With the precondition, a split that later loses its sites only
degrades to a harmless extra indirection.

== Scoping of the candidate maps

After 'Language.PureScript.Backend.IR.Linker.qualifyTopRefs' every
reference to a top-level binding is 'Imported', and QNames are globally
unique, so top-level candidates live in one module-wide map. Local
binder names are unique only per top-level site
('Language.PureScript.Backend.IR.Uniquify' — GUC is per-site), so local
candidates are collected, counted, and rewritten independently per
site: a saturated site in one site must not qualify a same-named binder
of another.

== Names

All minted names are deterministic — the shared supply is deliberately
not used, since a draw here would shift the numbering of every
@$kont@\/@$tmp@ name minted downstream (see
"Language.PureScript.Backend.IR.Supply"). The schemes @\<f\>$w@
(worker), @\<f\>$p\<i\>@ (wrapper parameters) and @\<f\>$u\<i\>@ (named
interior unused parameters) cannot collide with source identifiers
(no @$@ in PureScript identifiers), with freshened binders
(@\<name\>$\<digits\>@), with flattening helpers (@$kont\<n\>@,
@$tmp\<n\>@), or with CoreFn 'GenIdent's (which start with @$@).

The worker keeps the original chain's binders, so GUC is preserved: the
wrapper's parameters are fresh, and worker/wrapper of a top-level split
are separate sites anyway. An /interior/ 'ParamUnused' of the chain
becomes a fresh named parameter of the worker (never referenced), so
'ParamUnused' stays a trailing run (Note [n-ary abstraction]); the
trailing run itself is kept unused and dropped by the Lua backend.

== Pipeline placement

Runs twice. The early run sits between the post-merge optimize\/dce
fixpoint (so manifest arities are measured after inlining settles) and
the post-uncurry fixpoint (which dead-code-eliminates wrappers with no
remaining references and beta-reduces worker pastes), ahead of
floatIn\/magicDo\/flattenDeepBinds — the latter recognises the n-ary
chains and spines this pass emits. Effect-shaped bindings are mostly
left curried at that point: thunk-forcing call sites only appear once
magicDo has run, so their spines are still partial there.

The late run (issue #200) sits after flattenDeepBinds and catches the
two saturated families that do not exist early: the effect-run spines
magicDo completes — @f(a)(b)(EffectRunArg)@, saturating the manifest
chain @λa.λb.λ_@ whose trailing thunk parameter the worker absorbs
(the rewritten call is still an effect run, recognised by its trailing
marker — see 'Language.PureScript.Backend.IR.Types.isEffectRun') — and
the @$kont@ helpers minted by flattening, saturated by construction. A
dce pass then drops the wrappers whose sites were all saturated.

== Rerun

The late run meets the early run's output, so the candidate
classification distinguishes it: a binding whose manifest chain body is
exactly the delegate call to its own worker ('delegatesTo') is a
wrapper from an earlier run — it is not split again (that would mint a
duplicate @\<f\>$w@ binding) but re-registers its arity, so saturated
sites that appeared /between/ the runs (e.g. minted by call-site
pastes) are still rewritten to the existing worker. A non-wrapper
candidate whose @\<f\>$w@ name is nonetheless taken (call-site inlining
can paste a worker's body back into its wrapper) is left alone
entirely. On anything else a rerun is a no-op, so the pass stays
idempotent.
-}
module Language.PureScript.Backend.IR.Uncurry
  ( uncurryWorkerWrapper

    -- * Shapes of the split
    -- $shapes
  , manifestChain
  , delegatesTo
  ) where

import Control.Lens (cosmosOf, toListOf, transformOf)
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
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , WasRewritten
  , getAnn
  , listGrouping
  , noAnn
  , paramName
  , refLocal
  , rewrittenIf
  , setAnn
  , subexpressions
  , unwindApp
  , pattern Abs
  )

{- $shapes
The two recognisers of the split's own output.
"Language.PureScript.Backend.IR.AbsorbEffectThunk" consumes the same
shapes — it widens a worker's arity, so it must agree with this pass on
what a worker's curried chain and its delegate call look like.
-}

{- | Split every qualifying binding into worker and wrapper and rewrite
the saturated call sites to direct worker calls. The 'Set' argument is
the @inline never@ veto collected by the optimizer; those bindings are
left alone (the pragma declares sharing intent for the name as-is).
-}
uncurryWorkerWrapper ∷ Set QName → UberModule → (UberModule, WasRewritten)
uncurryWorkerWrapper neverNames uber@UberModule {..} =
  ( uber
      { uberModuleBindings = bindings'
      , uberModuleExports = exports'
      }
  , rewrittenIf
      (not (Map.null topSplit) || topDelegateSites || anyLocalRewrite)
  )
 where
  -- Names already bound at the top level: a candidate whose worker name
  -- is among them was split by an earlier run of this pass (only this
  -- pass mints @$w@ names) and may not mint the name a second time.
  topLevelQNames ∷ Set QName
  topLevelQNames =
    Set.fromList (fst <$> (listGrouping =<< uberModuleBindings))

  -- Top-level candidates: manifest arity ≥ 2, not vetoed — classified
  -- against the output of an earlier run (see the module haddock's
  -- Rerun section). A wrapper delegating to its own worker re-registers
  -- its arity so saturated sites that appeared since the split still
  -- reach the worker; a candidate whose worker name is otherwise taken
  -- is left alone entirely; the rest split as usual.
  topDelegating ∷ Map (Qualified Name) Int
  topParams ∷ Map (Qualified Name) (NonEmpty (Parameter Ann))
  (topDelegating, topParams) =
    bimap Map.fromList Map.fromList $
      partitionEithers
        [ classified
        | (QName modname name, expr) ← listGrouping =<< uberModuleBindings
        , QName modname name `Set.notMember` neverNames
        , let qualified = Imported modname name
        , Just (params, body) ← [manifestChain expr]
        , classified ←
            if delegatesTo (workerOf qualified) params body
              then [Left (qualified, length params)]
              else
                [ Right (qualified, params)
                | QName modname (workerName name)
                    `Set.notMember` topLevelQNames
                ]
        ]

  -- One saturated site anywhere in the module qualifies a top-level
  -- candidate; sites are every binding right-hand side and every export.
  siteExprs ∷ [Exp]
  siteExprs =
    (snd <$> (listGrouping =<< uberModuleBindings))
      <> (snd <$> uberModuleExports)

  topCounts ∷ Map (Qualified Name) Int
  topCounts =
    Map.unionsWith
      (+)
      (censusIn (Map.union (length <$> topParams) topDelegating) <$> siteExprs)

  topSplit ∷ Map (Qualified Name) (NonEmpty (Parameter Ann))
  topSplit =
    Map.filterWithKey
      (\q _ → Map.findWithDefault 0 q topCounts > 0)
      topParams

  topSplitArities ∷ Map (Qualified Name) Int
  topSplitArities = length <$> topSplit

  -- Whether a saturated site of an already-split wrapper was rewritten
  -- to its worker — a rewrite with no accompanying split, which the
  -- 'WasRewritten' signal must still report.
  topDelegateSites ∷ Bool
  topDelegateSites =
    any
      (\q → Map.findWithDefault 0 q topCounts > 0)
      (Map.keys topDelegating)

  processedBindings ∷ [Grouping (QName, Exp)]
  bindingRewrites ∷ [Bool]
  (processedBindings, bindingRewrites) =
    unzip (processGrouping <$> uberModuleBindings)
   where
    processGrouping ∷ Grouping (QName, Exp) → (Grouping (QName, Exp), Bool)
    processGrouping grouping =
      ( fmap (second fst) processed
      , any (snd . snd) (listGrouping processed)
      )
     where
      processed = fmap (second processSite) grouping

  processedExports ∷ [(Name, Exp)]
  exportRewrites ∷ [Bool]
  (processedExports, exportRewrites) =
    unzip
      [ ((name, e), rewrite)
      | (name, expr) ← uberModuleExports
      , let (e, rewrite) = processSite expr
      ]

  anyLocalRewrite ∷ Bool
  anyLocalRewrite = or bindingRewrites || or exportRewrites

  exports' = processedExports

  -- Split the qualifying top-level bindings of the processed module,
  -- worker to the left of its wrapper (Note [Incremental free-reference
  -- counting] visits right to left, so a binding may only be referenced
  -- by material to its right).
  bindings' ∷ [Grouping (QName, Exp)]
  bindings' = splitTop =<< processedBindings
   where
    splitTop = \case
      Standalone (qname, expr) →
        Standalone <$> splitMember (qname, expr)
      RecursiveGroup members →
        [RecursiveGroup (NE.fromList (splitMember =<< toList members))]

    splitMember ∷ (QName, Exp) → [(QName, Exp)]
    splitMember (qname@(QName modname name), expr)
      | Imported modname name `Map.member` topSplit
      , Just (params, body) ← manifestChain expr =
          let workerQName = QName modname (workerName name)
              workerRef = Imported modname (workerName name)
              (worker, wrapper) =
                workerAndWrapper (getAnn expr) name workerRef params body
           in [(workerQName, worker), (qname, wrapper)]
      | otherwise = [(qname, expr)]

  -- Process one top-level site: collect its local candidates, qualify
  -- them by their in-site saturated-site counts, then in one bottom-up
  -- sweep rewrite the saturated sites (top-level and local) and splice
  -- the qualifying Let bindings into worker/wrapper pairs.
  processSite ∷ Exp → (Exp, Bool)
  processSite expr = (transformOf subexpressions step expr, siteRewrites)
   where
    -- The site's Let binders, for the taken-name check: a local @$w@
    -- name can only have been minted by an earlier run of this pass,
    -- and it is always Let-bound.
    letBoundNames ∷ Set Name
    letBoundNames =
      Set.fromList
        [ name
        | Let _ groupings _ ← toListOf (cosmosOf subexpressions) expr
        , (_ann, name, _rhs) ← listGrouping =<< toList groupings
        ]

    -- Local candidates, classified like the top-level ones: delegating
    -- wrappers re-register, candidates with a taken worker name are
    -- left alone, the rest may split.
    localDelegating ∷ Map Name Int
    localParams ∷ Map Name (NonEmpty (Parameter Ann))
    (localDelegating, localParams) =
      bimap Map.fromList Map.fromList $
        partitionEithers
          [ classified
          | Let _ groupings _ ← toListOf (cosmosOf subexpressions) expr
          , (_ann, name, rhs) ← listGrouping =<< toList groupings
          , Just (params, body) ← [manifestChain rhs]
          , classified ←
              if delegatesTo (Local (workerName name)) params body
                then [Left (name, length params)]
                else
                  [ Right (name, params)
                  | workerName name `Set.notMember` letBoundNames
                  ]
          ]

    localCounts ∷ Map (Qualified Name) Int
    localCounts =
      censusIn
        ( Map.mapKeys
            Local
            (Map.union (length <$> localParams) localDelegating)
        )
        expr

    localSplit ∷ Map Name (NonEmpty (Parameter Ann))
    localSplit =
      Map.filterWithKey
        (\n _ → Map.findWithDefault 0 (Local n) localCounts > 0)
        localParams

    siteRewrites ∷ Bool
    siteRewrites =
      not (Map.null localSplit)
        || any
          (\n → Map.findWithDefault 0 (Local n) localCounts > 0)
          (Map.keys localDelegating)

    actives ∷ Map (Qualified Name) Int
    actives =
      Map.unions
        [ topSplitArities
        , topDelegating
        , Map.mapKeys Local (length <$> localSplit)
        , Map.mapKeys Local localDelegating
        ]

    step ∷ Exp → Exp
    step e = case saturatedSite actives e of
      Just (q, args) →
        AppN (getAnn e) (Ref noAnn (workerOf q)) (NE.fromList args)
      Nothing → case e of
        Let ann groupings body
          | any memberSplits (listGrouping =<< toList groupings) →
              Let ann (NE.fromList (spliceGrouping =<< toList groupings)) body
        _ → e

    memberSplits ∷ (Ann, Name, Exp) → Bool
    memberSplits (_ann, name, _rhs) = name `Map.member` localSplit

    spliceGrouping
      ∷ Grouping (Ann, Name, Exp) → [Grouping (Ann, Name, Exp)]
    spliceGrouping = \case
      Standalone member → Standalone <$> spliceMember member
      RecursiveGroup members →
        [RecursiveGroup (NE.fromList (spliceMember =<< toList members))]

    spliceMember ∷ (Ann, Name, Exp) → [(Ann, Name, Exp)]
    spliceMember member@(ann, name, rhs)
      | name `Map.member` localSplit
      , Just (params, body) ← manifestChain rhs =
          let (worker, wrapper) =
                workerAndWrapper
                  (getAnn rhs)
                  name
                  (Local (workerName name))
                  params
                  body
           in [(noAnn, workerName name, worker), (ann, name, wrapper)]
      | otherwise = [member]

--------------------------------------------------------------------------------
-- Worker and wrapper construction ---------------------------------------------

{- | Build the worker (the n-ary lambda over the original binders and
body) and the wrapper (the curried delegate under the original name).
The wrapper takes over the original root annotation: an @inline@ pragma
stays attached to the name it was declared for.
-}
workerAndWrapper
  ∷ Ann
  -- ^ The original right-hand side's root annotation
  → Name
  -- ^ The binding's own name (the wrapper keeps it)
  → Qualified Name
  -- ^ How call sites reference the worker
  → NonEmpty (Parameter Ann)
  -- ^ The manifest chain's parameters
  → Exp
  -- ^ The manifest chain's body
  → (Exp, Exp)
workerAndWrapper rootAnn name workerRef params body = (worker, wrapper)
 where
  worker = AbsN noAnn (nameInteriorUnused name params) body
  wrapper =
    setAnn rootAnn $
      foldr
        (Abs noAnn . ParamNamed noAnn)
        (AppN noAnn (Ref noAnn workerRef) (refLocal <$> wrapperParams))
        (toList wrapperParams)
  wrapperParams ∷ NonEmpty Name
  wrapperParams =
    NE.fromList
      [ Name (nameToText name <> "$p" <> Text.pack (show i))
      | i ← [1 .. length params]
      ]

{- | Replace each /interior/ 'ParamUnused' with a fresh named (never
referenced) parameter, keeping the trailing run unused: 'ParamUnused'
must stay a trailing run (Note [n-ary abstraction]).
-}
nameInteriorUnused
  ∷ Name → NonEmpty (Parameter Ann) → NonEmpty (Parameter Ann)
nameInteriorUnused fname params = NE.fromList (zipWith rename [1 ..] ps)
 where
  ps = toList params
  trailingUnused =
    length (takeWhile (isNothing . paramName) (reverse ps))
  interiorCount = length ps - trailingUnused
  rename ∷ Int → Parameter Ann → Parameter Ann
  rename i = \case
    ParamUnused ann
      | i <= interiorCount →
          ParamNamed
            ann
            (Name (nameToText fname <> "$u" <> Text.pack (show i)))
    p → p

--------------------------------------------------------------------------------
-- Recognition -----------------------------------------------------------------

{- | The manifest chain of a right-hand side: the parameters of the
directly-nested unary lambdas (nothing may intervene) and the innermost
body, when the chain is at least two deep — the shapes worth splitting.
-}
manifestChain ∷ Exp → Maybe (NonEmpty (Parameter Ann), Exp)
manifestChain expr = case peel expr of
  (p1 : p2 : ps, body) → Just (p1 :| (p2 : ps), body)
  _ → Nothing
 where
  peel ∷ Exp → ([Parameter Ann], Exp)
  peel = \case
    -- The singleton pattern: a multi-parameter 'AbsN' is already a
    -- worker and is not peeled.
    Abs _ann param body → first (param :) (peel body)
    e → ([], e)

{- | Recognise the wrapper this pass itself built: the manifest chain's
body is exactly the delegate call — the given worker reference applied
to the chain's parameters in order. Used by the rerun classification
(see the module haddock's Rerun section) to tell an already-split
binding from a fresh candidate.
-}
delegatesTo ∷ Qualified Name → NonEmpty (Parameter Ann) → Exp → Bool
delegatesTo workerRef params body = case body of
  AppN _ann (Ref _refAnn ref) args →
    ref == workerRef
      && length args == length params
      && and (NE.zipWith isParamRef params args)
  _ → False
 where
  isParamRef ∷ Parameter Ann → Exp → Bool
  isParamRef param arg = case (paramName param, arg) of
    (Just name, Ref _ann (Local name')) → name == name'
    _ → False

{- | Match a saturated call site: a nested /unary/ application spine
headed by a reference to a candidate, applying exactly as many
arguments as the candidate's arity. An over-application contains this
node as its inner prefix, and a longer flattened look-through is never
taken: 'AppN' argument lists are not spines (Note [n-ary application]).
-}
saturatedSite
  ∷ Map (Qualified Name) Int → Exp → Maybe (Qualified Name, [Exp])
saturatedSite arities e = case unwindApp e of
  (Ref _ann q, args)
    | Just arity ← Map.lookup q arities
    , length args == arity →
        Just (q, args)
  _ → Nothing

{- | Count the saturated sites of each candidate within one expression.
Absent keys have no sites.
-}
censusIn ∷ Map (Qualified Name) Int → Exp → Map (Qualified Name) Int
censusIn arities expr =
  Map.fromListWith
    (+)
    [ (q, 1)
    | node ← toListOf (cosmosOf subexpressions) expr
    , Just (q, _args) ← [saturatedSite arities node]
    ]

workerName ∷ Name → Name
workerName name = Name (nameToText name <> "$w")

workerOf ∷ Qualified Name → Qualified Name
workerOf = \case
  Imported modname name → Imported modname (workerName name)
  Local name → Local (workerName name)
