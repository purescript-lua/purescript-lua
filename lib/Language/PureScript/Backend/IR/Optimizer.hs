module Language.PureScript.Backend.IR.Optimizer where

import Control.Lens (over, toListOf, transformOf, universeOf)
import Control.Monad.Writer.CPS (WriterT, runWriterT, tell)
import Data.Foldable (foldrM)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Map qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import GHC.Generics (Generically (..))
import Language.PureScript.Backend.IR.DCE (eliminateDeadCode)
import Language.PureScript.Backend.IR.FlattenDeepBinds (flattenDeepBindsM)
import Language.PureScript.Backend.IR.FloatIn (floatIn)
import Language.PureScript.Backend.IR.Inliner (Annotation (..))
import Language.PureScript.Backend.IR.Linker
  ( UberModule (..)
  , foreignAccessorQName
  )
import Language.PureScript.Backend.IR.MagicDo (magicDo)
import Language.PureScript.Backend.IR.Names
  ( FieldName
  , ModuleName
  , Name (..)
  , PropName
  , QName (..)
  , Qualified (Imported, Local)
  , qualifiedQName
  )
import Language.PureScript.Backend.IR.Pass
  ( Invariant (..)
  , Pass (..)
  , PassCheckFailure
  , Step (..)
  , runSteps
  , runStepsChecked
  )
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName, runSupply)
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (SumType)
  , Ann
  , Capture (..)
  , Exp
  , Grouping (..)
  , Parameter (..)
  , PrimOp (..)
  , RawExp (..)
  , RewriteRuleM
  , Usage (..)
  , WasRewritten (..)
  , alphaEq
  , countFreeRef
  , countFreeRefUsage
  , countFreeRefs
  , ctorId
  , freshenBinders
  , getAnn
  , isEffectRun
  , isForeignImport
  , isNonRecursiveLiteral
  , lets
  , listGrouping
  , literalBool
  , literalFloat
  , literalInt
  , literalString
  , paramName
  , primNot
  , refImported
  , rewriteExpBottomUpM
  , setAnn
  , subexpressions
  , substituteCopyM
  , substituteMoveM
  , thenRewrite
  , unwindApp
  )
import Language.PureScript.Backend.IR.Uncurry (uncurryWorkerWrapper)
import Language.PureScript.Backend.IR.Uniquify (uniquifyNames)

optimizedUberModule ∷ UberModule → UberModule
optimizedUberModule uber =
  runSupply (runSteps (optimizerPipeline (collectInlinePolicy uber)) uber)

{- | 'optimizedUberModule' with every pass's contract checked by the
linter, failing with the name of the offending pass. Used by the test
suite always, and by the CLI behind the @--lint-ir@ flag.
-}
optimizedUberModuleChecked ∷ UberModule → Either PassCheckFailure UberModule
optimizedUberModuleChecked uber =
  runSupply
    (runStepsChecked (optimizerPipeline (collectInlinePolicy uber)) uber)

{- | The IR optimization pipeline. The argument is the inlining policy
collected once from the pristine module before any pass runs: later
rewrites may strip annotations, so every directive keys off a name (see
Note [Inline annotations and inlining heuristics]).
-}
optimizerPipeline ∷ InlinePolicy → [Step]
optimizerPipeline policy =
  [ -- The entry pass (issue #139): establishes the global-uniqueness
    -- condition (GUC = 'UniqueBinders') that every
    -- following pass requires and preserves.
    RunPass uniquifyPass
  , RunFixpoint "optimize+dce" (optimizePass :| [dcePass])
  , -- by merging foreign bindings into the main bindings, we can
    -- unblock even more optimizations, e.g. inline foreign bindings.
    RunPass mergeForeignsPass
  , RunFixpoint "optimize+dce-post-merge" (optimizePass :| [dcePass])
  , -- Split curried bindings into n-ary workers and curried wrappers
    -- and rewrite the saturated call sites to direct worker calls
    -- (issue #24). Runs after the post-merge fixpoint, so manifest
    -- arities are measured once inlining has settled. See
    -- Language.PureScript.Backend.IR.Uncurry.
    RunPass uncurryPass
  , -- The post-uncurry fixpoint dead-code-eliminates wrappers with no
    -- remaining references and reduces the n-ary redexes that pasting
    -- a single-use worker into its one call site produces.
    RunFixpoint "optimize+dce-post-uncurry" (optimizePass :| [dcePass])
  , -- Float a Let-bound value down into the single IfThenElse branch that
    -- uses it (issue #136). Runs after DCE (a dead binding is simply gone,
    -- never worth sinking) and outside any fixpoint: it preserves every
    -- free-reference count, so the count-driven inline/DCE decisions stay
    -- settled. A structural rule could still fire on the moved Let — e.g.
    -- a sink can leave both branches of an IfThenElse alpha-equivalent
    -- for removeIfWithEqualBranches — but chasing such second-order
    -- opportunities is deliberately traded away against re-running the
    -- whole fixpoint after the pass. Runs before magicDo/flattenDeepBinds
    -- (which see the final placement of every Let). See
    -- Language.PureScript.Backend.IR.FloatIn.
    RunPass floatInPass
  , -- Magic-do is the final lowering (issue #46): it relies on the unique
    -- naming established by 'uniquifyNames' and preserves it, and must run
    -- after dead-code elimination so the statements it introduces for
    -- `discard` are not dropped as dead. See
    -- Language.PureScript.Backend.IR.MagicDo.
    RunPass magicDoPass
  , -- Budgeted call-site inlining of dictionary methods (issue #180), the
    -- cure for non-Effect/ST monadic chains that compile to nested closure
    -- chains. Runs only here, after magicDo has lowered the Effect/ST chains:
    -- inlining a bind before that would leave magicDo a chain it can no
    -- longer recognise. The inlined methods' constructor matches then meet
    -- the case-of-known-constructor folds (#177/#213/#214), collapsing
    -- Maybe/Either/Writer/State chains into straight-line code. Code growth
    -- is bounded by 'inlineSizeBudget'.
    RunFixpoint "specialize+dce" (specializePass :| [dcePass])
  , -- Rebuild sharing for the foreign-accessor reads that dissolution
    -- and the call-site pastes above duplicated: a read surviving at
    -- two or more sites is re-bound to its linker name, which stage-2
    -- promotion then turns into a chunk local (issue #248). Runs after
    -- the last pass that can multiply reads and before the final
    -- flattening. See 'shareForeignAccessors'.
    RunPass shareAccessorsPass
  , -- Flatten the remaining deeply-nested expression trees (issues #104,
    -- #108): continuation/bind chains of any monad (lambda-lifted
    -- into $kont helpers) and applicative/flipped-bind application
    -- spines (A-normalised into $tmp locals). Runs after magicDo (which
    -- consumes Effect/ST chains, leaving only non-Effect/ST ones) and
    -- likewise consumes and preserves the unique naming.
    -- See Language.PureScript.Backend.IR.FlattenDeepBinds.
    RunPass flattenDeepBindsPass
  ]
 where
  uniquifyPass =
    Pass
      { passName = "uniquify"
      , passRun = conservatively . pure . uniquifyNames
      , passRequires = wellScoped
      , passEnsures = guc
      }
  -- The pre-magicDo optimize pass does no call-site inlining: an inlined
  -- Effect/ST @bind@ is one magicDo can no longer recognise (issue #180).
  optimizePass =
    Pass
      { passName = "optimize"
      , passRun = optimizeModule SkipCallSites policy
      , passRequires = guc
      , passEnsures = guc
      }
  -- The post-magicDo pass adds budgeted call-site inlining (issue #180): with
  -- Effect/ST chains already lowered, only non-Effect/ST methods remain to
  -- specialize, and inlining them lets the constructor folds collapse the
  -- chain to straight-line code.
  specializePass =
    Pass
      { passName = "specialize"
      , passRun = optimizeModule InlineCallSites policy
      , passRequires = guc
      , passEnsures = guc
      }
  dcePass =
    Pass
      { passName = "dce"
      , passRun = pure . eliminateDeadCode
      , passRequires = guc
      , passEnsures = guc
      }
  mergeForeignsPass = gucPass "mergeForeigns" mergeForeignsIntoBindings
  uncurryPass =
    Pass
      { passName = "uncurry"
      , passRun = pure . uncurryWorkerWrapper (uncurryVeto policy)
      , passRequires = guc
      , passEnsures = guc
      }
  floatInPass = gucPass "float-in" floatIn
  shareAccessorsPass = gucPass "share-accessors" shareForeignAccessors
  magicDoPass =
    Pass
      { passName = "magicDo"
      , passRun = conservatively . magicDo
      , passRequires = guc
      , passEnsures = guc
      }
  flattenDeepBindsPass =
    Pass
      { passName = "flattenDeepBinds"
      , passRun = conservatively . flattenDeepBindsM
      , passRequires = guc
      , passEnsures = guc
      }

  gucPass ∷ Text → (UberModule → UberModule) → Pass
  gucPass name run =
    Pass
      { passName = name
      , passRun = conservatively . pure . run
      , passRequires = guc
      , passEnsures = guc
      }

  -- Run-once passes report a conservative 'Rewritten' — only fixpoint
  -- members (optimize, dce) need a precise signal (see 'passRun').
  conservatively ∷ SupplyM UberModule → SupplyM (UberModule, WasRewritten)
  conservatively = fmap (,Rewritten)

  wellScoped ∷ Set Invariant
  wellScoped = Set.singleton WellScoped

  -- 'WellApplied' rides along with GUC at every boundary after the
  -- entry pass: it holds trivially while all nodes are unary, and once
  -- a pass introduces n-ary nodes, the pass that breaks their
  -- well-formedness is blamed at its own boundary.
  guc ∷ Set Invariant
  guc = Set.fromList [WellScoped, UniqueBinders, WellApplied]

mergeForeignsIntoBindings ∷ UberModule → UberModule
mergeForeignsIntoBindings uberModule@UberModule {..} =
  uberModule
    { uberModuleForeigns = []
    , uberModuleBindings =
        map Standalone uberModuleForeigns <> uberModuleBindings
    }

{- | Rebuild sharing for foreign-accessor reads duplicated during
optimization (issue #248). An unannotated accessor dissolves into its
use sites like any cheap projection (the Deref tier of
Note [Complexity and Capture gate inlining]), and call-site inlining
multiplies the pasted read further: a dictionary method resolved at
several sites pastes one field read per site. A field read repeated per
site loses to a shared binding once stage-2 promotion
('Language.PureScript.Backend.Lua.Promote') turns that binding into a
chunk local, so this pass counts the reads that survived the pipeline
and re-binds every accessor whose read occurs at two or more sites to
its linker name, rewriting the reads to references.

Runs once, after the specialize fixpoint has finished pasting (see
'optimizerPipeline'). Only unannotated reads participate: a read
carrying @inline always@ is pasted per site on explicit request, and a
@never@ accessor never dissolved in the first place (see
Note [Inline annotations and inlining heuristics]). The re-bound
accessor is inserted right after its module's 'ForeignImport' binding,
where the module-init order guarantees the foreign table is already
initialized; the reads it replaces sit in bindings placed after every
foreign table ('mergeForeignsIntoBindings' front-loads them all) or in
exports.
-}
shareForeignAccessors ∷ UberModule → UberModule
shareForeignAccessors uber@UberModule {uberModuleBindings, uberModuleExports}
  | Map.null shared = uber
  | otherwise =
      uber
        { uberModuleBindings =
            insertAccessorBindings
              (fmap (fmap (fmap rewriteExp)) uberModuleBindings)
        , uberModuleExports = fmap (fmap rewriteExp) uberModuleExports
        }
 where
  -- Unannotated accessor reads, keyed by the QName the linker
  -- originally bound the accessor to, with one representative
  -- expression per key (every copy of a read is identical). Only reads
  -- whose module still has its 'ForeignImport' binding participate —
  -- always the case for a well-scoped module, since the read itself
  -- references the foreign table.
  shared ∷ Map QName Exp
  shared =
    Map.fromListWith (\_new old → old) accessorReads
      `Map.restrictKeys` sharedNames
   where
    sharedNames =
      Map.keysSet $
        Map.filter (> 1) $
          Map.fromListWith (+) [(qname, 1 ∷ Natural) | (qname, _) ← accessorReads]

  accessorReads ∷ [(QName, Exp)]
  accessorReads =
    [ (qname, node)
    | expr ←
        (snd <$> (listGrouping =<< uberModuleBindings))
          <> (snd <$> uberModuleExports)
    , node ← universeOf subexpressions expr
    , isNothing (getAnn node)
    , Just qname ← [foreignAccessorQName node]
    , qname `Set.notMember` boundNames
    , qnameModuleName qname `Set.member` modulesWithForeign
    ]

  -- Top-level names already bound: an accessor kept by an @inline
  -- never@ veto reaches this pass as a binding, and its reads are
  -- already references.
  boundNames ∷ Set QName
  boundNames =
    Set.fromList (fst <$> (listGrouping =<< uberModuleBindings))

  modulesWithForeign ∷ Set ModuleName
  modulesWithForeign =
    Set.fromList
      [ qnameModuleName qname
      | Standalone (qname, ForeignImport {}) ← uberModuleBindings
      ]

  rewriteExp ∷ Exp → Exp
  rewriteExp = transformOf subexpressions \node →
    case foreignAccessorQName node of
      Just qname@(QName modname name)
        | isNothing (getAnn node)
        , qname `Map.member` shared →
            refImported modname name
      _ → node

  insertAccessorBindings
    ∷ [Grouping (QName, Exp)] → [Grouping (QName, Exp)]
  insertAccessorBindings = concatMap \case
    grouping@(Standalone (qname, ForeignImport {})) →
      grouping
        : [ Standalone (accessor, rhs)
          | (accessor, rhs) ← Map.toAscList shared
          , qnameModuleName accessor == qnameModuleName qname
          ]
    grouping → [grouping]

{- | Every inlining directive of the module, keyed by binding name.
Collected once from the pristine module: later rewrites can drop an
annotation off its node (e.g. constant folding replaces a binding's root
with a fresh one), so decisions key off names rather than re-reading
annotations after optimization.
See Note [Inline annotations and inlining heuristics].
-}
data InlinePolicy = InlinePolicy
  { policyAlways ∷ Set QName
  {- ^ pasted at every use site; a bare-Ref alias to such a name is
  never dissolved (issue #171)
  -}
  , policyNever ∷ Set QName
  -- ^ never pasted anywhere
  , policyArity ∷ Map QName Natural
  -- ^ pasted exactly at call sites applying at least N arguments
  , policyFields ∷ Map QName (Map PropName Annotation)
  -- ^ @.label@ policies: fields of a dictionary record binding
  , policyAppliedFields ∷ Map QName (Map PropName Annotation)
  -- ^ @...label@ policies: fields of a record a binding returns
  }
  deriving stock (Generic, Show)
  deriving (Semigroup, Monoid) via (Generically InlinePolicy)

collectInlinePolicy ∷ UberModule → InlinePolicy
collectInlinePolicy UberModule {uberModuleBindings, uberModuleForeigns} =
  foldMap fromBinding $
    [(qname, expr) | Standalone (qname, expr) ← uberModuleBindings]
      -- Foreign accessors merge into the bindings mid-pipeline
      -- ('mergeForeignsIntoBindings'), after the policy is collected, so
      -- their annotations are read here.
      <> uberModuleForeigns
 where
  fromBinding ∷ (QName, Exp) → InlinePolicy
  fromBinding (qname, expr) = rootPolicy <> fieldsPolicy
   where
    rootPolicy = case getAnn expr of
      Just Always → mempty {policyAlways = Set.singleton qname}
      Just Never → mempty {policyNever = Set.singleton qname}
      Just (Arity n) → mempty {policyArity = Map.singleton qname n}
      _ → mempty

    fieldsPolicy = case objectFields expr of
      Just (depth, props)
        | anns ←
            Map.fromList
              [(prop, a) | (prop, value) ← props, Just a ← [getAnn value]]
        , not (Map.null anns) →
            if depth == 0
              then mempty {policyFields = Map.singleton qname anns}
              else mempty {policyAppliedFields = Map.singleton qname anns}
      _ → mempty

  -- The object literal a binding evaluates or returns, along with the
  -- number of lambda parameters peeled on the way to it — the shape
  -- accessor annotations are attached to at translation.
  objectFields ∷ Exp → Maybe (Int, [(PropName, Exp)])
  objectFields = go 0
   where
    go ∷ Int → Exp → Maybe (Int, [(PropName, Exp)])
    go depth = \case
      AbsN _ params body → go (depth + length params) body
      Let _ _ body → go depth body
      LiteralObject _ props → Just (depth, props)
      _ → Nothing

{- | Names the uncurry pass may not split: rewriting their call sites to
@$w@ worker calls would hide those sites from the name-keyed policies.
-}
uncurryVeto ∷ InlinePolicy → Set QName
uncurryVeto InlinePolicy {policyNever, policyArity, policyAppliedFields} =
  policyNever <> Map.keysSet policyArity <> Map.keysSet policyAppliedFields

-- | Free-reference counts keyed by the referenced qualified name.
type FreeRefs = Map (Qualified Name) Natural

{- Note [Incremental free-reference counting]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'withBinding' decides whether to inline a 'Standalone' binding partly on
whether it is referenced exactly once. Counting those references naively —
folding 'countFreeRefs' over the whole module for each binding — costs
O(bindings × module size) per 'optimizeModule' run, and the run itself
repeats inside the optimize+dce fixpoint (issue #142).

Instead we thread one 'FreeRefs' map through the fold, holding the exact
invariant:

    counts = free references over the current accumulator
           = (bindingExprs =<< bindings) <> map snd exports

'foldrM' visits bindings right-to-left, and a binding may only be referenced
by material to its right (Note [Sequential scoping of Let bindings]), so by
the time a binding is visited every one of its referencers is already in the
accumulator and its count in 'counts' is final. The map is built once from
the exports and updated by a known delta at each step:

  * binding kept   → its own expression joins the accumulator, so add its
    free refs: @counts ⊕ countFreeRefs expr@.
  * binding inlined → each of its @k@ occurrences is replaced by a copy of
    the expression, so add @k@ copies of the expression's free refs and drop
    the binding's own entry: @delete qn (counts ⊕ k · countFreeRefs expr)@.
    Under the pass's unique-binders invariant a 'Standalone' RHS never names
    its own binder, so @countFreeRefs expr@ cannot reintroduce @qn@.
  * recursive group → its members are never inlined; their (mutually
    recursive) refs join the accumulator like any kept binding.

Besides removing the quadratic cost, this counts against the live
(post-substitution) accumulator rather than a stale snapshot of the original
bindings, so the use-once decision no longer misjudges a binding whose
references changed earlier in the same run (issue #143).
-}
optimizeModule
  ∷ CallSiteInlining
  → InlinePolicy
  → UberModule
  → SupplyM (UberModule, WasRewritten)
optimizeModule inlining policy UberModule {..} = runWriterT do
  -- See Note [Incremental free-reference counting]
  let initialCounts =
        Map.unionsWith (+) (countFreeRefs . snd <$> uberModuleExports)
  (_finalCounts, bindings, exports) ←
    foldrM withBinding (initialCounts, [], uberModuleExports) uberModuleBindings
  uberModuleBindings' ←
    traverse (traverse (traverse optimizeExp)) bindings
  uberModuleExports' ← traverse (traverse optimizeExp) exports
  pure
    UberModule
      { uberModuleForeigns
      , uberModuleBindings = uberModuleBindings'
      , uberModuleExports = uberModuleExports'
      }
 where
  -- Top-level bindings the call-site inliner may resolve and paste
  -- (issue #180): Standalone RHSs, minus the @inline never@ set. Built from
  -- the pristine input bindings, a stable snapshot for this run; the
  -- specialize+dce fixpoint rebuilds it each round as bindings settle. Empty
  -- when call-site inlining is off, so the two inline rules never fire — the
  -- pre-magicDo runs, where inlining an Effect/ST @bind@ would rob magicDo of
  -- the un-inlined chain it recognises (see 'optimizerPipeline').
  inlineEnv ∷ InlineEnv
  inlineEnv = case inlining of
    SkipCallSites → mempty
    InlineCallSites →
      Map.fromList
        [ (qualifiedQName qname, expr)
        | Standalone (qname, expr) ← uberModuleBindings
        , qname `Set.notMember` policyNever policy
        ]

  -- An @inline never@ name may not be pasted at all; an @inline arity=N@
  -- name is pasted only at qualifying call sites — pasting the whole
  -- binding would reach under-applied sites too.
  vetoedWholeBinding ∷ QName → Bool
  vetoedWholeBinding qname =
    qname `Set.member` policyNever policy
      || qname `Map.member` policyArity policy

  -- The top-level counterpart of 'isInlinableExpr', diverging from it
  -- twice (issue #171). The Always directive is consulted by name —
  -- 'policyAlways', not the RHS root annotation, which an earlier paste
  -- may have planted there: a binding that merely received an
  -- always-annotated body must not itself turn unconditionally
  -- inlinable. And a bare-Ref alias to an @inline always@ binding is
  -- never dissolved: substituting it would multiply the target's use
  -- sites right before Always pastes its body into every one of them,
  -- destroying the alias that is the better materialization point on
  -- both size and speed. The target's body pastes into the surviving
  -- alias instead.
  topLevelInlinable ∷ QName → Exp → Bool
  topLevelInlinable qname expr =
    qname `Set.member` policyAlways policy
      || (isInlinableValue expr && not (aliasesAlwaysBinding expr))

  aliasesAlwaysBinding ∷ Exp → Bool
  aliasesAlwaysBinding = \case
    Ref _ ref → maybe False (`Set.member` policyAlways policy) (refQName ref)
    _ → False

  -- Whether 'withBinding' may drop a whole top-level binding by inlining it
  -- into its use sites. Off exactly when call-site inlining is on, because the
  -- two are unsound together: 'inlineEnv' is a snapshot taken before this run
  -- mutates anything, so a host binding it holds may still name a binding that
  -- 'withBinding' drops mid-run. Pasting that stale host (into a later binding
  -- or an export) then reintroduces a reference to the dropped binding — a
  -- dangling name the later DCE cannot repair, since DCE removes bindings but
  -- never references. Leaving every binding in place during a call-site pass
  -- keeps the snapshot honest; the following DCE still collects whatever the
  -- pasting left unreferenced. The pre-magicDo runs, with no env to go stale,
  -- keep the whole-binding inlining (see Note [Incremental free-reference
  -- counting] and 'optimizerPipeline').
  mayInlineWholeBinding ∷ Bool
  mayInlineWholeBinding = case inlining of
    SkipCallSites → True
    InlineCallSites → False

  -- Every expression rewrite and every top-level inlining reports into
  -- the pass's 'WasRewritten' result; nothing else in this pass changes
  -- the module, so a converged module reports 'Unmodified'.
  optimizeExp ∷ Exp → WriterT WasRewritten SupplyM Exp
  optimizeExp e = do
    (e', rewritten) ← lift (optimizedExpressionM policy inlineEnv e)
    e' <$ tell rewritten

  -- See Note [Incremental free-reference counting]
  withBinding
    ∷ Grouping (QName, Exp)
    → (FreeRefs, [Grouping (QName, Exp)], [(Name, Exp)])
    → WriterT
        WasRewritten
        SupplyM
        (FreeRefs, [Grouping (QName, Exp)], [(Name, Exp)])
  withBinding binding (counts, bindings, exports) =
    case binding of
      Standalone (qname, expr0) → do
        expr ← optimizeExp expr0
        -- See Note [Inline annotations and inlining heuristics]
        let qn = qualifiedQName qname
            occurrences = Map.findWithDefault 0 qn counts
            isUsedOnce = occurrences == 1
        if mayInlineWholeBinding
          && not (vetoedWholeBinding qname)
          && not (isForeignImport expr)
          && (topLevelInlinable qname expr || isUsedOnce)
          then do
            -- The binding is dropped from the module in favor of the
            -- substituted copies: a rewrite even when it had no
            -- occurrences left to substitute.
            tell Rewritten
            (bindings', exports') ←
              lift $
                (,)
                  <$> substituteInBindings qname expr bindings
                  <*> substituteInExports qname expr exports
            -- Substituting drops the binding's own occurrences and pastes
            -- one copy of its free refs per occurrence replaced.
            let pastedRefs = fmap (* occurrences) (countFreeRefs expr)
                counts' = Map.delete qn (Map.unionWith (+) counts pastedRefs)
            pure (counts', bindings', exports')
          else
            -- The binding survives, so its refs now live in the accumulator.
            pure
              ( Map.unionWith (+) counts (countFreeRefs expr)
              , Standalone (qname, expr) : bindings
              , exports
              )
      RecursiveGroup recGroup → do
        recGroup' ← traverse (traverse optimizeExp) recGroup
        -- Recursive-group members are never inlined; their (mutually
        -- recursive) refs now live in the accumulator.
        let counts' =
              foldl'
                (\m (_, e) → Map.unionWith (+) m (countFreeRefs e))
                counts
                (toList recGroup')
        pure (counts', RecursiveGroup recGroup' : bindings, exports)

-- Cross-entry substitution: the host entry's binders give no uniqueness
-- guarantee against the inlinee's, so every copy is freshened
-- ('substituteCopyM'), even when the inlinee's own entry is dropped.
substituteInBindings
  ∷ QName
  -- ^ Substitute this qualified name
  → Exp
  -- ^ For this expression
  → [Grouping (QName, Exp)]
  -- ^ inside these bindings
  → SupplyM [Grouping (QName, Exp)]
substituteInBindings qname inlinee = traverse \case
  Standalone (qname', expr') →
    Standalone . (qname',)
      <$> substituteCopyM (qualifiedQName qname) inlinee expr'
  RecursiveGroup recGroup →
    RecursiveGroup
      <$> traverse
        (traverse (substituteCopyM (qualifiedQName qname) inlinee))
        recGroup

substituteInExports ∷ QName → Exp → [(Name, Exp)] → SupplyM [(Name, Exp)]
substituteInExports qname inlinee = traverse \case
  (name, expr) →
    (name,) <$> substituteCopyM (qualifiedQName qname) inlinee expr

{- | Top-level bindings visible to call-site inlining (issue #180), keyed by
the qualified name a reference uses. Built once per 'optimizeModule' run from
the 'Standalone' bindings, minus the @inline never@ set. Recursive-group
members are deliberately absent, so a self-referential dictionary is never
unfolded (Note [Eta reduction is unsound]).
-}

{- | Whether an 'optimizeModule' run performs call-site inlining (issue
#180). Off before magic-do so it cannot dismantle the Effect/ST @bind@ chains
magic-do recognises; on in the specialize fixpoint that runs after (see
'optimizerPipeline').
-}
data CallSiteInlining = InlineCallSites | SkipCallSites

type InlineEnv = Map (Qualified Name) Exp

{- | The largest expression the call-site inliner will paste, GHC's
unfolding-use-threshold analogue, sized in IR nodes. Code growth is the
transform's main risk (issue #180); this bounds it. Deliberately generous
enough to admit an uncurried monad-method worker (a folded Maybe/Either
match), the payload the cascade is built to collapse.
-}
inlineSizeBudget ∷ Natural
inlineSizeBudget = 64

-- | Node count of an expression, for 'inlineSizeBudget'.
expSize ∷ RawExp ann → Natural
expSize e = 1 + sum (expSize <$> toListOf subexpressions e)

{- | The largest expression the Deref and KnownSize inlining tiers paste
(Note [Complexity and Capture gate inlining]), sized in IR nodes like
'inlineSizeBudget' but far below it: these tiers admit duplication at
every use site, so growth scales with the use count.
-}
smallInlineBudget ∷ Natural
smallInlineBudget = 16

{- | How costly an expression is to duplicate, ordered by escalation.
Combines by taking the worse classification.
See Note [Complexity and Capture gate inlining].
-}
data Complexity = Trivial | Deref | KnownSize | NonTrivial
  deriving stock (Show, Eq, Ord)

instance Semigroup Complexity where
  (<>) = max

instance Monoid Complexity where
  mempty = Trivial

{- | Bottom-up cost classification. 'Trivial': a reference or a
scalar/empty literal.
'Deref': a chain of cheap reads (projection, index, length, tag) over a
Trivial base. 'KnownSize': an abstraction or a non-empty literal — a
bounded allocation. Everything that computes is 'NonTrivial', and
unlisted constructors deliberately land there, so a new node kind is
conservative by default. A string literal above 128 characters counts
as an allocation rather than a scalar: 'expSize' sees one node, but
duplicating the payload is not free.
-}
complexityOf ∷ RawExp ann → Complexity
complexityOf = \case
  Ref {} → Trivial
  LiteralInt {} → Trivial
  LiteralFloat {} → Trivial
  LiteralChar {} → Trivial
  LiteralBool {} → Trivial
  LiteralString _ann s
    | Text.length s > 128 → KnownSize
    | otherwise → Trivial
  LiteralArray _ann exprs
    | null exprs → Trivial
    | otherwise → KnownSize <> foldMap complexityOf exprs
  LiteralObject _ann props
    | null props → Trivial
    | otherwise → KnownSize <> foldMap (complexityOf . snd) props
  ObjectProp _ann base _prop → Deref <> complexityOf base
  ArrayIndex _ann base _idx → Deref <> complexityOf base
  ArrayLength _ann base → Deref <> complexityOf base
  ReflectCtor _ann base → Deref <> complexityOf base
  DataArgumentByIndex _ann _algTy _idx base → Deref <> complexityOf base
  AbsN _ann _params body → KnownSize <> complexityOf body
  _ → NonTrivial

{- | Pure wrapper for tests and standalone use: runs the rewrite with
its own supply and no inlining environment. Production code uses
'optimizedExpressionM' so all passes share one supply.
-}
optimizedExpression ∷ Exp → Exp
optimizedExpression = runSupply . fmap fst . optimizedExpressionM mempty mempty

optimizedExpressionM
  ∷ InlinePolicy → InlineEnv → Exp → SupplyM (Exp, WasRewritten)
optimizedExpressionM policy env =
  -- See Note [Eta reduction is unsound]
  rewriteExpBottomUpM
    ( constantFolding
        `thenRewrite` reduceObjectProp
        `thenRewrite` sinkProjectionIntoLet
        `thenRewrite` reduceKnownConstructor
        `thenRewrite` reduceKnownCtorRefRead env
        `thenRewrite` propagateKnownCtorThroughLet env
        `thenRewrite` resolveDictionaryProp policy env
        `thenRewrite` inlineAnnotatedProjection policy env
        `thenRewrite` inlineSaturatedCall policy env
        `thenRewrite` betaReduce
        `thenRewrite` removeUnreachableThenBranch
        `thenRewrite` removeUnreachableElseBranch
        `thenRewrite` removeIfWithEqualBranches
        `thenRewrite` flipNegatedIf
        `thenRewrite` reduceBooleanIf
        `thenRewrite` inlineLocalBindings
    )

{- Note [IR is assumed well-typed]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The optimizer assumes its input IR is well-typed -- it has already passed the
PureScript type checker -- and several rewrites rely on that rather than
re-checking. 'constantFolding' rewrites @Eq True b@ to @b@ on the grounds that
@b@ must then be a 'Bool', and 'betaReduce' substitutes an argument for a
parameter without checking their types match. A rewrite must not introduce an
assumption the type checker would not already guarantee.
-}
constantFolding ∷ Applicative m ⇒ RewriteRuleM m Ann
constantFolding =
  pure . \case
    Eq _ (LiteralBool _ a) (LiteralBool _ b) →
      Just $ literalBool $ a == b
    Eq _ (LiteralBool _ True) b →
      -- 'b' must be of type Bool; see Note [IR is assumed well-typed]
      Just b
    Eq _ (LiteralInt _ a) (LiteralInt _ b) →
      Just $ literalBool $ a == b
    Eq _ (LiteralFloat _ a) (LiteralFloat _ b) →
      Just $ literalBool $ a == b
    Eq _ (LiteralChar _ a) (LiteralChar _ b) →
      Just $ literalBool $ a == b
    Eq _ (LiteralString _ a) (LiteralString _ b) →
      Just $ literalBool $ a == b
    -- See Note [IR primops] and Note [Folding primops follows Lua 5.1]
    PrimBinOp _ op a b → foldPrimBinOp op a b
    PrimNot _ a → foldPrimNot a
    _ → Nothing

{- Note [Folding primops follows Lua 5.1]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The primop folds must reproduce the /target/ semantics (Lua 5.1, where
every number is an IEEE double), not the host's, or a folded literal
would evaluate differently from the code it replaced (see Note [IR
primops]). The per-operator caveats:

  * Integer @+@/@-@/@*@ fold with exact integer arithmetic, but only
    while every operand and the result stay within ±2^53. Past that a
    Lua double cannot represent consecutive integers, so the exact
    compile-time value and the runtime double value could disagree; the
    fold bails rather than argue with the printer over literal forms.
  * Integer @%@ is @a - floor(a/b)*b@ in Lua 5.1 — its sign follows the
    divisor, which coincides with Haskell's 'mod' (not 'rem', and not
    C's @%@). Undefined at @b == 0@ (the runtime yields NaN), left to the
    runtime.
  * Float @+@/@-@/@*@//@/@ fold in double semantics, but only to a
    /finite/ result: Lua has no inf/nan numeric literal (the printer
    emits @math.huge@ / @(0/0)@ expressions), so @1.0 / 0.0@ is left to
    the runtime rather than folded to a non-literal shape.
  * @..@ folds string with string only. Lua coerces a number operand on
    concat with a version- and build-dependent format, so a number is
    never reproduced at compile time.
  * Comparisons fold on two numbers (int or finite float); strings and
    chars are left alone, because Lua orders strings by bytes while the
    IR literal carries semantic 'Text'.
  * @and@/@or@ fold when both operands are boolean, and additionally
    collapse a known-boolean first operand (@true and b == b@,
    @false or b == b@, and the two annihilators): sound because Lua
    @and@/@or@ short-circuit, so dropping the second operand is exactly
    what the runtime does.
-}

-- | The IEEE-double exactness ceiling; integer folds bail beyond it.
maxSafeInteger ∷ Integer
maxSafeInteger = 2 ^ (53 ∷ Int)

{- | Fold a binary primop over literal operands, or 'Nothing' when a
rule declines. See Note [Folding primops follows Lua 5.1].
-}
foldPrimBinOp ∷ PrimOp → Exp → Exp → Maybe Exp
foldPrimBinOp op l r = case (op, l, r) of
  (PrimAdd, LiteralInt _ a, LiteralInt _ b) → intFold a b (a + b)
  (PrimSub, LiteralInt _ a, LiteralInt _ b) → intFold a b (a - b)
  (PrimMul, LiteralInt _ a, LiteralInt _ b) → intFold a b (a * b)
  (PrimMod, LiteralInt _ a, LiteralInt _ b)
    | b /= 0 → intFold a b (a `mod` b)
  (PrimAdd, LiteralFloat _ a, LiteralFloat _ b) → floatFold (a + b)
  (PrimSub, LiteralFloat _ a, LiteralFloat _ b) → floatFold (a - b)
  (PrimMul, LiteralFloat _ a, LiteralFloat _ b) → floatFold (a * b)
  (PrimDiv, LiteralFloat _ a, LiteralFloat _ b) → floatFold (a / b)
  (PrimConcat, LiteralString _ a, LiteralString _ b) →
    Just (literalString (a <> b))
  (PrimLt, _, _) → literalBool . (== LT) <$> numericCompare l r
  (PrimLe, _, _) → literalBool . (/= GT) <$> numericCompare l r
  (PrimGt, _, _) → literalBool . (== GT) <$> numericCompare l r
  (PrimGe, _, _) → literalBool . (/= LT) <$> numericCompare l r
  (PrimAnd, LiteralBool _ a, LiteralBool _ b) → Just (literalBool (a && b))
  (PrimAnd, LiteralBool _ True, b) → Just b
  (PrimAnd, LiteralBool _ False, _) → Just (literalBool False)
  (PrimOr, LiteralBool _ a, LiteralBool _ b) → Just (literalBool (a || b))
  (PrimOr, LiteralBool _ True, _) → Just (literalBool True)
  (PrimOr, LiteralBool _ False, b) → Just b
  _ → Nothing
 where
  intFold ∷ Integer → Integer → Integer → Maybe Exp
  intFold a b result
    | all ((<= maxSafeInteger) . abs) [a, b, result] = Just (literalInt result)
    | otherwise = Nothing

  floatFold ∷ Double → Maybe Exp
  floatFold result
    | isFinite result = Just (literalFloat result)
    | otherwise = Nothing

  numericCompare ∷ Exp → Exp → Maybe Ordering
  numericCompare a b = case (a, b) of
    (LiteralInt _ x, LiteralInt _ y) → Just (compare x y)
    (LiteralFloat _ x, LiteralFloat _ y)
      | isFinite x, isFinite y → Just (compare x y)
    _ → Nothing

  isFinite ∷ Double → Bool
  isFinite d = not (isNaN d || isInfinite d)

{- | Fold logical @not@ over a boolean literal, and eliminate a double
negation (@not (not e)@ ⟶ @e@, sound since @e@ is a 'Bool'). See
Note [IR primops].
-}
foldPrimNot ∷ Exp → Maybe Exp
foldPrimNot = \case
  LiteralBool _ b → Just (literalBool (not b))
  PrimNot _ e → Just e
  _ → Nothing

{- | Folds a record projection into the record constructor:
@{ foo: 1, bar: 2 }.foo@ becomes @1@, and a projection through a record
update takes the patched value (or reaches into the updated record when
the field is not patched).

'PropName' keys are static labels — no computed-key form exists — and
the type checker forbids duplicate labels in record literals and
updates, so a plain 'lookup' is exact (see Note [IR is assumed
well-typed]). A miss is only possible on ill-typed input, where the
rule declines.

The discarded fields are never evaluated — the same call DCE makes when
it drops an unused binding unconditionally.

The folded value takes the projection's own root annotation, not the
field's: the result occupies the projection's position in the tree. A
field can hold a foreign accessor annotated @Just Always@ (see
Note [Foreign bindings structure emitted by the Linker]), and passing
that annotation along would make whatever binding receives the fold
unconditionally inlinable, duplicating it at every use site.
-}
reduceObjectProp ∷ Applicative m ⇒ RewriteRuleM m Ann
reduceObjectProp =
  pure . \case
    ObjectProp ann (LiteralObject _ props) prop →
      setAnn ann <$> List.lookup prop props
    ObjectProp ann (ObjectUpdate _ obj patches) prop →
      Just case List.lookup prop (toList patches) of
        Just patched → setAnn ann patched
        Nothing → ObjectProp ann obj prop
    _ → Nothing

{- | @(let … in body).label ===> let … in body.label@

Bindings evaluate first either way, so the move is behaviour-preserving
under strict evaluation, and the label is static, so nothing can be
captured. Pasting a record constructor into a projected application site
(see 'inlineAnnotatedProjection') leaves exactly this shape behind once
'betaReduce' let-binds a non-trivial argument; sinking the projection
lets 'reduceObjectProp' finish the resolution.

A constructor field read over a 'Let' is the same residue with a data
constructor inside — an inlined paste of code matching on a constructor
argument — and sinks by the same argument, bringing the read to where
'reduceKnownConstructor' can reach the constructor.
-}
sinkProjectionIntoLet ∷ Applicative m ⇒ RewriteRuleM m Ann
sinkProjectionIntoLet =
  pure . \case
    ObjectProp ann (Let letAnn binds body) prop →
      Just $ Let letAnn binds (ObjectProp ann body prop)
    DataArgumentByIndex ann algTy i (Let letAnn binds body) →
      Just $ Let letAnn binds (DataArgumentByIndex ann algTy i body)
    _ → Nothing

{- | Case-of-known-constructor for algebraic types (issue #177), the
'reduceObjectProp' twin for data constructors:

  * @ReflectCtor (K a₁ … aₙ)@ — a tag read over a saturated /sum-type/
    constructor application — folds to @K@'s tag string. The surrounding
    equality test then meets 'constantFolding' and
    'removeUnreachableThenBranch' / 'removeUnreachableElseBranch', which
    collapse the decision tree to its live branch.
  * @DataArgumentByIndex i (K a₁ … aₙ)@ — a field read, the shape the
    pattern matcher emits — folds to @aᵢ@.

A constructor application is the curried unary-'App' spine
@App (… (App (Ctor …) a₁) …) aₙ@ that translation and the pattern
matcher build. The fold fires only when the spine is /saturated/ (as
many arguments as the constructor declares fields), so a partial
application — still a function — is left alone.

'ReflectCtor' folds for 'SumType' only: product constructors omit the
tag slot in the generated Lua (see the @Ctor@ case of
'Language.PureScript.Backend.Lua.fromIR'), so a product-type tag read
has no tag string to fold to — at runtime it aliases the first field.
A field read folds for either shape, but only when the read's algebraic
type matches the constructor's: the type decides the runtime slot
offset (past the tag for sums, from slot 1 for products), so folding a
mismatched — necessarily ill-typed — read would return a different
value than the compiled slot access reads.

Discarded arguments are dropped, not evaluated — the discipline
'reduceObjectProp' applies to discarded record fields and DCE applies to
unused bindings. A dropped argument cannot skip an 'Effect': effects are
unrun thunks here, run only when applied, so an effect that must run is
the /kept/ argument (the field a match actually binds), never a dropped
one; the only casualties are the pure divergence or partiality that DCE
already elides. The folded value takes the read node's own annotation,
not the argument's, for the reason spelled out on 'reduceObjectProp'.
-}
reduceKnownConstructor ∷ Applicative m ⇒ RewriteRuleM m Ann
reduceKnownConstructor =
  pure . \case
    ReflectCtor ann scrutinee
      | (Ctor _ SumType modName tyName ctorName fields, args) ←
          unwindApp scrutinee
      , length args == length fields →
          Just $ LiteralString ann (ctorId modName tyName ctorName)
    -- A tag read over a conditional of constructors distributes into the
    -- branches, where each meets the rule above and folds to its tag string
    -- (issue #180): an inlined comparison (@compare@\/@>=@) is an if-tree of
    -- 'Ordering' constructors, and @reflectCtor@ over it would otherwise build
    -- an 'Ordering' table at runtime only to read the tag back off it. Guarded
    -- so it fires only when every branch folds, so it never leaves a residual
    -- read nor grows a conditional whose branches are not constructors.
    ReflectCtor ann (IfThenElse ifAnn cond t e)
      | reflectFoldsThrough t
      , reflectFoldsThrough e →
          Just $ IfThenElse ifAnn cond (ReflectCtor ann t) (ReflectCtor ann e)
    DataArgumentByIndex ann algTy index scrutinee
      | (Ctor _ ctorAlgTy _ _ _ fields, args) ← unwindApp scrutinee
      , algTy == ctorAlgTy
      , length args == length fields
      , Just arg ← viaNonEmpty head (List.genericDrop index args) →
          Just (setAnn ann arg)
    _ → Nothing

{- | Whether @ReflectCtor@ over this expression folds away completely: it is a
saturated sum-type constructor application (folds to its tag string) or a
conditional whose branches all do. Only then does 'reduceKnownConstructor'
distribute a tag read into an 'IfThenElse', so the rewrite never leaves a
residual read behind nor grows a conditional over non-constructor branches.
-}
reflectFoldsThrough ∷ RawExp ann → Bool
reflectFoldsThrough = \case
  IfThenElse _ _ t e → reflectFoldsThrough t && reflectFoldsThrough e
  scrutinee
    | (Ctor _ SumType _ _ _ fields, args) ← unwindApp scrutinee →
        length args == length fields
  _ → False

{- | Case-of-known-constructor through a let-bound scrutinee (issue #214).

'reduceKnownConstructor' only fires on a constructor that is in place, and a
scrutinee read more than once is never in place: 'betaReduce' Let-binds a
non-trivial argument rather than substitute it (Note [Beta reduction and
local inlining share an inlining guard]), and a dictionary method reads its
scrutinee several times — a tag test, a payload read, a fallthrough tag
test. So an inlined and beta-reduced method lands on

> let v = Just (x + 1) in
>   if justTag == ReflectCtor v then … DataArgumentByIndex 0 v …
>   else if nothingTag == ReflectCtor v then Nothing else …

and nothing folds: the rules see @ReflectCtor (Ref v)@ and
@DataArgumentByIndex 0 (Ref v)@, never the constructor.

This propagates a known constructor from a 'Standalone' Let binding into the
binder's reads. When the RHS is a saturated 'Ctor' application and the binder
is read /only/ through constructor-eliminating reads:

  * each @ReflectCtor v@ becomes the tag string (sum types only, as in
    'reduceKnownConstructor');
  * each field read (@DataArgumentByIndex i v@, with the constructor's own
    algebraic type — see 'reduceKnownConstructor' for why a mismatch does
    not fold) becomes a fresh field-binder @fᵢ@ bound once to the iᵗʰ
    argument — GHC's case-binder to field-binder split, so an argument
    read at several sites is evaluated once, not duplicated (the
    discipline 'betaReduce' keeps);
  * the @v@ binding is dropped, its unread arguments discarded with the same
    licence 'reduceKnownConstructor' drops a field read's siblings.

Trivial and dead field-binders then inline or DCE away, and the folded reads
let the surrounding @Eq@ / @if@ meet 'constantFolding' and
'removeUnreachable*', collapsing the decision tree to its live arm.

The rule declines when the binder is read as a whole value — a sibling RHS,
or a non-eliminating position such as an argument to a function. Dropping it
would dangle the reference, and keeping it while binding the fields would
duplicate the arguments. A product-type @ReflectCtor@ read has no tag slot to
fold to, so it too leaves a whole-value read and the rule declines. GUC keeps
the fresh field-binders unique and the binder resolved by name.

The RHS's constructor is recognised either as an in-place 'Ctor' node or, via
the inline environment, through a 'Ref' to a top-level constructor binding
(issue #180). A user-written @Right x@ compiles to a reference to the
@Data.Either.Right@ worker, which 'inlineSaturatedCall' leaves in place — its
'Ctor' RHS is not a lambda, and pasting the worker would only rebuild the same
@(function … end)(x)@ the reference already denotes, more deeply nested. So
without the through-a-reference resolution the constructor test the inlined
@bind@ introduces (@justTag == ReflectCtor v@) never folds, and the collapsed
monadic chain stays a deeply-nested @if@\/@let@ tree. Resolving the reference
only to read its arity and tag introduces no 'Ctor' node, so a chain that does
not fold is not pessimised into pasted constructor thunks.
-}
propagateKnownCtorThroughLet ∷ InlineEnv → RewriteRuleM SupplyM Ann
propagateKnownCtorThroughLet env = \case
  Let ann groupings body
    | Just (before, (name, algTy, fields, args, tag), after) ←
        findCtorBinding (toList groupings)
    , all ((== 0) . countFreeRefGrouping name) (before <> after)
    , countFreeRef (Local name) body > 0
    , not (hasWholeValueRead name algTy fields body) → do
        let readIndices = readFieldIndices name algTy body
        freshFields ←
          Map.fromList
            <$> traverse
              (\i → (i,) <$> freshName "$field")
              (toList readIndices)
        let body' = foldCtorReads name algTy tag freshFields body
            fieldBinds =
              [ Standalone (Nothing, f, arg)
              | (i, f) ← Map.toAscList freshFields
              , Just arg ← [args !!? fromIntegral i]
              ]
        pure . Just $ case nonEmpty (before <> fieldBinds <> after) of
          Nothing → body'
          Just gs → Let ann gs body'
  _ → pure Nothing
 where
  -- The first Standalone binding whose RHS is a saturated constructor
  -- application, split out from its siblings.
  findCtorBinding
    ∷ [Grouping (Ann, Name, Exp)]
    → Maybe
        ( [Grouping (Ann, Name, Exp)]
        , (Name, AlgebraicType, [FieldName], [Exp], Text)
        , [Grouping (Ann, Name, Exp)]
        )
  findCtorBinding = go []
   where
    go
      ∷ [Grouping (Ann, Name, Exp)]
      → [Grouping (Ann, Name, Exp)]
      → Maybe
          ( [Grouping (Ann, Name, Exp)]
          , (Name, AlgebraicType, [FieldName], [Exp], Text)
          , [Grouping (Ann, Name, Exp)]
          )
    go _before [] = Nothing
    go before (grouping : after) = case grouping of
      Standalone (_bAnn, name, rhs)
        | Just (algTy, fields, args, tag) ← asKnownCtorApp rhs
        , length args == length fields
        , -- A self-referencing RHS cannot arise under GUC (a Standalone RHS
          -- does not see its own binder), but 'optimizedExpression' also runs
          -- on non-GUC input; dropping the binding would then dangle the
          -- field-binder that copied the reference (cf. 'inlineLocalBinding').
          countFreeRef (Local name) rhs == 0 →
            Just (reverse before, (name, algTy, fields, args, tag), after)
      _ → go (grouping : before) after

  -- A saturated constructor application, recognised either as an in-place
  -- 'Ctor' node or through a 'Ref' to a top-level constructor binding held in
  -- the inline environment (issue #180 — see the note on this function). The
  -- returned tag and field list come from the constructor's declaration; the
  -- arguments come from the application spine.
  asKnownCtorApp ∷ Exp → Maybe (AlgebraicType, [FieldName], [Exp], Text)
  asKnownCtorApp rhs = case unwindApp rhs of
    (Ctor _ algTy modName tyName ctorName fields, args) →
      Just (algTy, fields, args, ctorId modName tyName ctorName)
    (Ref _ ctorRef, args)
      | Just (Ctor _ algTy modName tyName ctorName fields) ←
          Map.lookup ctorRef env →
          Just (algTy, fields, args, ctorId modName tyName ctorName)
    _ → Nothing

  countFreeRefGrouping ∷ Name → Grouping (Ann, Name, Exp) → Natural
  countFreeRefGrouping name grouping =
    sum [countFreeRef (Local name) e | (_ann, _n, e) ← listGrouping grouping]

  -- True when some @Ref name@ is reached other than through a foldable
  -- eliminating read — the residue that would dangle if the binding dropped.
  hasWholeValueRead ∷ Name → AlgebraicType → [FieldName] → Exp → Bool
  hasWholeValueRead name algTy fields = go
   where
    go = \case
      ReflectCtor _ (Ref _ (Local n)) | n == name, SumType ← algTy → False
      -- An out-of-range index or a mismatched algebraic type reads no
      -- existing field, so it is not a foldable eliminating read: it falls
      -- through to the whole-value read below, forcing the rule to decline
      -- (as 'reduceKnownConstructor' does), rather than minting a fresh
      -- field-binder the argument list cannot bind. Well-typed input never
      -- indexes past the arity nor mistypes the read; the guards keep the
      -- rule sound on the non-GUC / generated input 'optimizedExpression'
      -- also runs on.
      DataArgumentByIndex _ readTy i (Ref _ (Local n))
        | n == name, readTy == algTy, i < fromIntegral (length fields) → False
      Ref _ (Local n) | n == name → True
      other → any go (toListOf subexpressions other)

  readFieldIndices ∷ Name → AlgebraicType → Exp → Set Natural
  readFieldIndices name algTy = go
   where
    go e = self e <> foldMap go (toListOf subexpressions e)
    self = \case
      DataArgumentByIndex _ readTy i (Ref _ (Local n))
        | n == name, readTy == algTy → Set.singleton i
      _ → mempty

  foldCtorReads
    ∷ Name
    → AlgebraicType
    → Text
    → Map Natural Name
    → Exp
    → Exp
  foldCtorReads name algTy tag freshFields = go
   where
    go = \case
      ReflectCtor rcAnn (Ref _ (Local n))
        | n == name, SumType ← algTy → LiteralString rcAnn tag
      DataArgumentByIndex daAnn readTy i (Ref _ (Local n))
        | n == name
        , readTy == algTy
        , Just f ← Map.lookup i freshFields →
            Ref daAnn (Local f)
      other → over subexpressions go other

{- | The through-a-reference companion of 'reduceKnownConstructor' — the
relationship 'resolveDictionaryProp' bears to 'reduceObjectProp'. A
user-written @Op f@ compiles to a saturated application of a /reference/
to the @Op@ worker binding, which 'inlineSaturatedCall' deliberately
leaves in place (its 'Ctor' RHS is not a lambda). A constructor-eliminating
read over that spine — the shape a directive-driven paste exposes —
would otherwise stall right before the fold: 'reduceKnownConstructor'
needs an in-place 'Ctor' head and 'propagateKnownCtorThroughLet' needs
the read behind a 'Let' binder. The reference is resolved through the
environment only for its declared fields and tag — no 'Ctor' node is
pasted — and discarded sibling arguments are dropped with the licence
'reduceKnownConstructor' spells out. The folded value takes the read
node's own annotation, not the argument's, for the reason spelled out
on 'reduceObjectProp'.
-}
reduceKnownCtorRefRead ∷ Applicative m ⇒ InlineEnv → RewriteRuleM m Ann
reduceKnownCtorRefRead env =
  pure . \case
    -- Field reads fold only at the constructor's own algebraic type, as
    -- in 'reduceKnownConstructor'.
    DataArgumentByIndex ann algTy i spine
      | Just (ctorAlgTy, _fields, args, _tag) ← saturatedCtorRefApp env spine
      , algTy == ctorAlgTy
      , Just arg ← args !!? fromIntegral i →
          Just (setAnn ann arg)
    -- Tag reads fold for sum types only, as in 'reduceKnownConstructor'.
    ReflectCtor ann spine
      | Just (SumType, _fields, _args, tag) ← saturatedCtorRefApp env spine →
          Just (LiteralString ann tag)
    _ → Nothing

{- | A non-empty, saturated application spine whose head references a
top-level constructor binding, resolved through the inline environment.
The returned tag and field list come from the constructor's declaration;
the arguments come from the spine.
-}
saturatedCtorRefApp
  ∷ InlineEnv → Exp → Maybe (AlgebraicType, [FieldName], [Exp], Text)
saturatedCtorRefApp env expr = case unwindApp expr of
  (Ref _ ctorRef, args@(_ : _))
    | Just (Ctor _ algTy modName tyName ctorName fields) ←
        Map.lookup ctorRef env
    , length args == length fields →
        Just (algTy, fields, args, ctorId modName tyName ctorName)
  _ → Nothing

{- | Resolve a method projection off a known top-level dictionary (issue
#180). When @dict@ is a reference to a top-level 'LiteralObject' binding,
@dict.method@ is replaced by the method expression itself — the concrete
@bind@ / @apply@ / @map@ — without inlining the rest of the dictionary. The
generic accessor @Control.Bind.bind = λdict. dict.bind@, once its @dict@
argument is inlined and beta-reduced, becomes exactly this @dict.bind@
projection, so this rule is what turns it into the concrete method a call
site can then reduce.

The projection over a 'LiteralObject' /literal/ is already handled by
'reduceObjectProp'; this is its through-a-reference companion, reading the
literal out of the environment. Reading a field of a known record is
behaviour-preserving, so the resolved method — freshened to keep the copied
binders unique while the dictionary binding survives — evaluates exactly as
the projection did.

It declines a method that names its own dictionary (a superclass or
recursive dictionary), which pasting would dangle or unfold forever, and one
larger than 'inlineSizeBudget'. The result takes the projection's own
annotation, never the method's, for the reason 'reduceObjectProp' spells out.

A @.label@ directive on the field replaces the budget: @never@ declines
outright, @always@ resolves regardless of size, and @arity=N@ defers to
'inlineAnnotatedProjection', which requires the projection to be applied.
The veto is best-effort rather than airtight: a dictionary referenced
exactly once is pasted whole by the use-once path in 'optimizeModule', and
'reduceObjectProp' then folds the projection without consulting any policy —
harmless, since sharing is moot at a single use site.
-}
resolveDictionaryProp ∷ InlinePolicy → InlineEnv → RewriteRuleM SupplyM Ann
resolveDictionaryProp policy env = \case
  ObjectProp ann (Ref _ dictName) prop
    | Just (LiteralObject _ props) ← Map.lookup dictName env
    , Just method ← List.lookup prop props
    , countFreeRef dictName method == 0
    , maybe
        (expSize method <= inlineSizeBudget)
        (== Always)
        (fieldPolicy policy dictName prop) →
        Just . setAnn ann <$> freshenBinders method
  _ → pure Nothing

-- | The @.label@ directive covering a projection of a top-level binding.
fieldPolicy ∷ InlinePolicy → Qualified Name → PropName → Maybe Annotation
fieldPolicy policy name prop =
  refQName name
    >>= (`Map.lookup` policyFields policy)
    >>= Map.lookup prop

{- | The @...label@ directive covering a projection out of an application
of a top-level binding.
-}
appliedFieldPolicy
  ∷ InlinePolicy → Qualified Name → PropName → Maybe Annotation
appliedFieldPolicy policy name prop =
  refQName name
    >>= (`Map.lookup` policyAppliedFields policy)
    >>= Map.lookup prop

{- | Resolve a projection under an accessor-form directive (the
@.label@ / @...label@ forms):

  * @.label arity=N@ — @(dict.label) a₁ … aₖ@, @k ≥ N@: the method is read
    out of the dictionary literal in the environment and pasted at the
    head of the spine, exactly as 'resolveDictionaryProp' would paste it,
    but only at a qualifying application.
  * @...label always@ — @(f x…).label@: the record constructor @f@ is
    pasted under the projection; 'betaReduce', 'sinkProjectionIntoLet'
    and 'reduceObjectProp' then collapse the projection to the selected
    field.
  * @...label arity=N@ — @((f x…).label) a₁ … aₖ@, @k ≥ N@: the same
    paste, gated on the arguments applied to the projection result.

Like the arity path of 'inlineSaturatedCall', an explicit directive
bypasses the size budget; the self-reference and 'pasteableRoot' guards
stay, and every pasted copy drops its annotations' claim to the binding
('setAnn' 'Nothing').
-}
inlineAnnotatedProjection ∷ InlinePolicy → InlineEnv → RewriteRuleM SupplyM Ann
inlineAnnotatedProjection policy env expr = case expr of
  ObjectProp ann inner label
    | (Ref _ fname, innerArgs@(_ : _)) ← unwindApp inner
    , Just Always ← appliedFieldPolicy policy fname label →
        pasteCtor ann fname innerArgs label
  (unwindApp → (ObjectProp ann inner label, args@(_ : _))) →
    case inner of
      Ref _ dictName
        | Just (Arity n) ← fieldPolicy policy dictName label
        , fromIntegral (length args) >= n
        , Just (LiteralObject _ props) ← Map.lookup dictName env
        , Just method ← List.lookup label props
        , countFreeRef dictName method == 0 →
            Just . rebuildSpine args . setAnn Nothing
              <$> freshenBinders method
      (unwindApp → (Ref _ fname, innerArgs@(_ : _)))
        | Just (Arity n) ← appliedFieldPolicy policy fname label
        , fromIntegral (length args) >= n → do
            pasted ← pasteCtor ann fname innerArgs label
            pure $ rebuildSpine args <$> pasted
      _ → pure Nothing
  _ → pure Nothing
 where
  pasteCtor
    ∷ Ann → Qualified Name → [Exp] → PropName → SupplyM (Maybe Exp)
  pasteCtor ann fname innerArgs label =
    case Map.lookup fname env of
      Just rhs
        | countFreeRef fname rhs == 0
        , pasteableRoot rhs → do
            rhs' ← freshenBinders rhs
            pure . Just $
              ObjectProp ann (rebuildSpine innerArgs (setAnn Nothing rhs')) label
      _ → pure Nothing

{- | Inline a top-level lambda binding into a saturated call site (issue
#180). When the head of an application spine references a top-level binding
whose RHS is a lambda, and the spine supplies at least the arguments the
lambda binds, the reference is replaced by a fresh copy of the lambda, which
'betaReduce' then reduces against the arguments. This is what specializes a
monad method to its call site: the concrete worker is pasted in, its
constructor matches meet 'reduceKnownConstructor' and
'propagateKnownCtorThroughLet', and the chain collapses to straight-line
code.

Pasting a lambda (a value) duplicates no work, and 'betaReduce' let-binds any
non-trivial argument rather than copy it into each use, so the reduction is
behaviour-preserving (issue #167). Growth is bounded by 'inlineSizeBudget'.
The rule declines a self-referential RHS, which cannot arise for a Standalone
binding under GUC but must not be unfolded on the non-GUC input the rewrite
also runs on (Note [Eta reduction is unsound] is the reason the environment
holds no recursive-group members either).

A binding under an @inline arity=N@ directive takes a different gate: the
site qualifies by argument count alone — at least N arguments applied — and
the explicit directive bypasses the size budget and the manifest-lambda
requirement (pasting a non-lambda value duplicates work, which is exactly
what the user signed for; in a pure language it is behaviour-preserving).
Below N arguments nothing pastes, not even the default guards: the
directive pins the binding as a shared reference at partial sites.
-}
inlineSaturatedCall ∷ InlinePolicy → InlineEnv → RewriteRuleM SupplyM Ann
inlineSaturatedCall policy env expr = case unwindApp expr of
  (Ref _ fname, args)
    | not (null args)
    , Just rhs ← Map.lookup fname env →
        case directedArity fname of
          Just arity
            | fromIntegral (length args) >= arity
            , countFreeRef fname rhs == 0
            , not (isForeignImport rhs)
            , pasteableRoot rhs →
                -- The pasted copy is no longer the directed binding, so
                -- it does not keep the directive annotation.
                Just . rebuildSpine args . setAnn Nothing
                  <$> freshenBinders rhs
          Just _underApplied → pure Nothing
          Nothing
            | AbsN _ params _ ← rhs
            , length args >= length params
            , countFreeRef fname rhs == 0
            , expSize rhs <= inlineSizeBudget →
                Just . rebuildSpine args <$> freshenBinders rhs
          _ → pure Nothing
  _ → pure Nothing
 where
  directedArity ∷ Qualified Name → Maybe Natural
  directedArity fname = refQName fname >>= (`Map.lookup` policyArity policy)

-- | Re-apply the arguments 'unwindApp' peeled, as a unary spine.
rebuildSpine ∷ [Exp] → Exp → Exp
rebuildSpine args head' = foldl' (\f a → AppN Nothing f (a :| [])) head' args

{- | 'inlineSaturatedCall' rebuilds the application spine as a unary chain,
so pasting an n-ary lambda root would produce an under-applied redex the
'WellApplied' lint rejects and exact-arity 'betaReduce' never repairs. Only
unary chains and non-lambda roots may be pasted. Directive-marked names are
excluded from the uncurry split ('uncurryVeto'), so their roots stay
translation-produced unary chains and this guard does not fire in practice.
-}
pasteableRoot ∷ Exp → Bool
pasteableRoot = \case
  AbsN _ (_ :| (_ : _)) _ → False
  _ → True

-- | The 'QName' a reference resolves to, when it names a top-level binding.
refQName ∷ Qualified Name → Maybe QName
refQName = \case
  Imported modname name → Just (QName modname name)
  Local _ → Nothing

{- Note [Beta reduction and local inlining share an inlining guard]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'betaReduce' and 'inlineLocalBinding' decide whether to paste an expression
into its use sites by the same test: paste only when re-evaluating it cannot
multiply work — the expression is cheap to re-evaluate ('isInlinableExpr': a
Ref, a literal, an @inline always@ node, or the Deref tier of
Note [Complexity and Capture gate inlining]), it is used at most once, or it
is a small closed abstraction whose uses all sit outside branches and
closures ('isDuplicatableClosedAbs', the KnownSize tier of the same Note).
Otherwise the expression stays behind a single 'Let' binding.

The two rules must agree, because they hand work to each other. When
'betaReduce' declines to substitute a redex it rewrites it to
@let param = arg in body@ rather than duplicating @arg@ (in a strict language
that would repeat @arg@'s evaluation at every occurrence). That 'Let' is then
visited by 'inlineLocalBinding', which faces the identical choice for the same
expression. Because the guards match, it declines too, so the pair reaches a
fixpoint in one bottom-up pass instead of oscillating.
-}

{- | (λx₁ … xₙ. M) N₁ … Nₙ ===> M[x₁ := N₁, …, xₙ := Nₙ]

Fires only at exact arity: any other argument count on a literal lambda
head is ill-formed ('WellApplied', Note [n-ary abstraction]). The unary
redex is the singleton case. Each pair reduces by the shared guard: the
argument is substituted when cheap, used at most once, or a small
duplicatable closed abstraction, and bound by a 'Let' otherwise; an
argument at a 'ParamUnused' position is dropped
with its evaluation — the same call DCE makes when it drops an unused
binding unconditionally. See Note [IR is assumed well-typed].
-}
betaReduce ∷ RewriteRuleM SupplyM Ann
betaReduce = \case
  redex@(AppN _ (AbsN _ params body) args)
    | length args == length params
    , -- Under GUC the parameters are pairwise-distinct binders. The rule
      -- is also exercised standalone on non-GUC input, where a repeated
      -- parameter name would let the first substitution steal the
      -- occurrences belonging to the last same-named parameter (the one
      -- Lua binds), so it declines rather than mis-substitute.
      distinctParamNames params
    , -- Do not reduce through a magic-do effect run (a thunk applied to the
      -- 'EffectRunArg' marker): the thunk is a chunk boundary magic-do
      -- introduced to keep each function under Lua's local-variable limit, and
      -- merging it into its parent would overflow that limit. The marker is
      -- magic-do's alone, so an ordinary nullary thunk (a dictionary accessor
      -- or newtype coercion applied to @Prim.undefined@) is not mistaken for
      -- one and reduces freely (issue #180, see 'isEffectRun').
      not (isEffectRun redex) → do
        (body', letBinds) ←
          foldlM reduceOne (body, []) (NE.zip params args)
        pure . Just $ case nonEmpty (reverse letBinds) of
          Nothing → body'
          Just binds → lets (Standalone <$> binds) body'
  _ → pure Nothing
 where
  reduceOne
    ∷ (Exp, [(Ann, Name, Exp)])
    → (Parameter Ann, Exp)
    → SupplyM (Exp, [(Ann, Name, Exp)])
  reduceOne (body, letBinds) (param, arg) = case param of
    ParamUnused _ann → pure (body, letBinds)
    ParamNamed paramAnn name
      -- See Note [Beta reduction and local inlining share an inlining guard]
      | usage ← countFreeRefUsage (Local name) body
      , isInlinableExpr arg
          || usageTotal usage <= 1
          || isDuplicatableClosedAbs arg usage →
          -- The λ is consumed by the rewrite, so the first inserted
          -- occurrence of the argument may keep its binder names
          -- ('substituteMoveM').
          (,letBinds) <$> substituteMoveM (Local name) arg body
      | otherwise →
          -- Bind the argument once; its evaluation happens a single time.
          pure (body, (paramAnn, name, arg) : letBinds)

  distinctParamNames ∷ NonEmpty (Parameter Ann) → Bool
  distinctParamNames params = length names == length (ordNub names)
   where
    names = mapMaybe paramName (toList params)

{- Note [Eta reduction is unsound]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The optimizer used to rewrite (λx. M x) to M whenever x was not free
in M. In a strict language this is not semantics-preserving: it moves
the evaluation of M from every call of the lambda to the point where
the lambda itself was constructed.

That breaks self-referential instance dictionaries (issue #32). For

  data Tree a = Leaf | Node { left ∷ Tree a, value ∷ a, right ∷ Tree a }
  derive instance genericTree ∷ Generic (Tree a) _
  instance eqTree ∷ Eq a ⇒ Eq (Tree a) where
    eq x y = genericEq x y

the method is deliberately eta-expanded by the user: the dictionary
chain built by genericEq contains `eqTree dictEq` — a self-reference —
and hiding it under λx λy is the documented PureScript way to break
the cycle (upstream purs relies on it too: its JS output keeps the
chain under the lambdas). Eta reduction rewrote the method to a bare
application chain

  eqTree = \dictEq → { eq = genericEq genericTree (… eqTree dictEq …) }

which recurses at dictionary-construction time: calling `eqTree d`
evaluates `eqTree d` eagerly and overflows the stack before any
comparison happens. Golden/GenericEqTwoTypes is the regression test
(two generic types, so the chain is multiply-used and the inliner
cannot mask the problem by inlining it under another lambda).

Reducing only special cases of M does not help either:

  * M is an application — may diverge (the case above);
  * M is a reference — a recursive-group member `f = λx. g x`
    becomes the value binding `f = g`, but the laziness analysis
    (CoreFn.Laziness.applyLazinessTransform) already ran on CoreFn
    and never saw it, so nothing wraps it in runtime-lazy and `g`
    may still be uninitialized when `f` is assigned;
  * M is an abstraction — the redex (λy. K) x is already handled by
    betaReduce, so nothing is left to gain.

Hence no eta reduction is performed at all.
-}

removeIfWithEqualBranches ∷ Applicative m ⇒ RewriteRuleM m Ann
removeIfWithEqualBranches e =
  pure case e of
    IfThenElse _ann _cond thenBranch elseBranch
      -- Alpha-equivalence, not (==): binder names in the branches may
      -- differ (e.g. after freshening) while the branches still compute
      -- the same value.
      | thenBranch `alphaEq` elseBranch →
          Just thenBranch
    _ → Nothing

{- | Drop a negated condition by swapping the branches:
@if not p then a else b@ ⟶ @if p then b else a@. Runs before
'reduceBooleanIf' so that @if not p then False else True@ normalises to
@p@ rather than stalling at @not (not p)@. Strictly removes one 'PrimNot'
from the condition, so it terminates. See Note [IR is assumed
well-typed].
-}
flipNegatedIf ∷ Applicative m ⇒ RewriteRuleM m Ann
flipNegatedIf =
  pure . \case
    IfThenElse ann (PrimNot _ cond) thenBranch elseBranch →
      Just (IfThenElse ann cond elseBranch thenBranch)
    _ → Nothing

{- | Collapse an if whose branches are the two boolean literals to the
condition or its negation:

  * @if p then True else False@ ⟶ @p@;
  * @if p then False else True@ ⟶ @not p@ (a 'PrimNot' — a node the IR
    only gained with the primops of issue #178).

Every 'Ord' comparison and @/=@ decays to this shape: their 'case' over
the result compiles to a two-way boolean decision tree, so once the
foreign comparison bodies lift to primops (#178) it is the dominant
residual. @p@ is a 'Bool' evaluated once with pure literal branches, so
the rewrite is semantics-preserving (see Note [IR is assumed
well-typed]).
-}
reduceBooleanIf ∷ Applicative m ⇒ RewriteRuleM m Ann
reduceBooleanIf =
  pure . \case
    IfThenElse _ cond (LiteralBool _ True) (LiteralBool _ False) →
      Just cond
    IfThenElse _ cond (LiteralBool _ False) (LiteralBool _ True) →
      Just (primNot cond)
    _ → Nothing

removeUnreachableThenBranch ∷ Applicative m ⇒ RewriteRuleM m Ann
removeUnreachableThenBranch e =
  pure case e of
    IfThenElse _ann (LiteralBool _ False) _unreachable elseBranch →
      Just elseBranch
    _ → Nothing

removeUnreachableElseBranch ∷ Applicative m ⇒ RewriteRuleM m Ann
removeUnreachableElseBranch e = pure case e of
  IfThenElse _ann (LiteralBool _ True) thenBranch _unreachable →
    Just thenBranch
  _ → Nothing

-- Inlining is a tricky business:
-- https://www.microsoft.com/en-us/research/wp-content/uploads/2002/07/inline.pdf

inlineLocalBindings ∷ RewriteRuleM SupplyM Ann
inlineLocalBindings = \case
  Let ann groupings body → do
    -- How many times each binder is referenced by the RHSs of the Let's
    -- groupings. Sequential scoping lets a later grouping name an earlier
    -- binder (Note [Sequential scoping of Let bindings]), and inlining touches
    -- only the body, so 'inlineLocalBinding' consults this to avoid pasting a
    -- second copy of a binding a sibling still references (see there). Counted
    -- once and shared across the fold — the RHSs are invariant across it — and
    -- lazy, so a Let whose bindings never reach the check pays nothing.
    let rhsRefCounts ∷ Map (Qualified Name) Natural
        rhsRefCounts =
          Map.unionsWith
            (+)
            [ countFreeRefs rhs
            | (_ann, _n, rhs) ← listGrouping =<< toList groupings
            ]
    (body', inlined) ←
      foldrM (inlineLocalBinding rhsRefCounts) (body, Unmodified) groupings
    pure case inlined of
      Rewritten → Just (Let ann groupings body')
      Unmodified → Nothing
  _ → pure Nothing

{- | Inline one binding into the Let's body when the heuristic wants it
/and/ the body actually references it — a zero-occurrence substitution
is a no-op and must not report a rewrite (the 'RewriteRule' contract),
or the optimize fixpoint would never converge.

The inlinee must not reference the binding's own name: substitution
never descends into its insertions, so a self-reference would keep the
occurrence count above zero and the rule firing forever (for the
non-GUC shape @let x = x in x@ the substitution is a textual no-op, so
the driver's repeat-until-Nothing loops — found by a hung CI run), and
the pasted copy's free self-reference would be captured by the very
binding it names. Under GUC this cannot arise — a Standalone RHS does
not see its own binder (Note [Sequential scoping of Let bindings]), so
a same-named reference in the RHS would be a duplicate binder upstream
— but 'optimizedExpression' is also exercised directly on non-GUC
input, where the rule must decline rather than loop or capture.
-}
inlineLocalBinding
  ∷ Map (Qualified Name) Natural
  -- ^ How many times each binder is referenced by the Let's grouping RHSs
  → Grouping (Ann, Name, Exp)
  → (Exp, WasRewritten)
  → SupplyM (Exp, WasRewritten)
inlineLocalBinding rhsRefCounts grouping (body, inlined) =
  case grouping of
    RecursiveGroup _grp → pure (body, inlined) -- Not inlining recursive bindings
    Standalone (_ann, Local → name, inlinee)
      | occurrences > 0
      , countFreeRef name inlinee == 0 -- no self-reference, see above
      , -- See Note [Beta reduction and local inlining share an inlining guard].
        -- A non-trivial inlinee a sibling grouping's RHS also references must
        -- not be inlined: substitution reaches only the body, so the sibling
        -- keeps its reference to the surviving binding, and a second copy in
        -- the body would evaluate the RHS twice -- duplicating any effect it
        -- performs (e.g. allocating a fresh mutable Ref, splitting one cell
        -- into two). 'occurrences' counts only the body, so the grouping RHSs
        -- are checked separately: absence from 'rhsRefCounts' means no sibling
        -- names it (the count map records no zero entries, and the binding's
        -- own RHS is excluded by the self-reference guard above).
        isInlinableExpr inlinee
          || ( (occurrences == 1 || isDuplicatableClosedAbs inlinee usage)
                 && name `Map.notMember` rhsRefCounts
             ) →
          -- The binding survives until DCE drops it, so the inserted copy
          -- must not reuse its binder names ('substituteCopyM').
          (,Rewritten) <$> substituteCopyM name inlinee body
      | otherwise → pure (body, inlined)
     where
      usage ∷ Usage
      usage = countFreeRefUsage name body
      occurrences ∷ Natural
      occurrences = usageTotal usage

{- Note [Complexity and Capture gate inlining]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Two small lattices refine the inlining heuristics beyond exact use
counts and flat size ceilings (issue #231):

  Complexity = Trivial < Deref < KnownSize < NonTrivial  ('complexityOf')
  Capture = CaptureNone < CaptureBranch < CaptureClosure
                                                   ('countFreeRefUsage')

'Complexity' prices duplicating an expression; 'Capture' locates a
binding's use sites relative to it. Together they admit two tiers past
the use-count rule:

  * Deref tier ('isInlinableExpr'): an expression of complexity at most
    'Deref' and size under 'smallInlineBudget' pastes at any use count.
    Re-reading a projection chain is semantics-preserving because
    PureScript records and module tables are write-once; the
    re-evaluation cost is a field read. The tier reaches all three
    guard sites — 'withBinding', 'betaReduce', 'inlineLocalBinding' —
    through the shared predicate.

  * KnownSize tier ('isDuplicatableClosedAbs', the two local sites
    only): a closed 'AbsN' under 'smallInlineBudget' whose bound name's
    uses all sit at 'CaptureNone' is substituted even when used many
    times, so a locally-bound combinator beta-reduces at every site.
    The 'CaptureNone' condition refuses to move the lambda literal into
    a branch or closure: paying a closure allocation per call of the
    surrounding function is the LuaJIT trace-abort pathology of issue
    #204, so closedness and small size alone do not admit duplication.

A 'NonTrivial' body is admitted by neither tier, so it is never
duplicated — under a branch, a closure, or anywhere else. It still
inlines when used at most once: that is relocation, not duplication,
and the FloatIn pass moves work into single branches deliberately.

'withBinding' gets no KnownSize tier on purpose: an uber-module
binding's uses sit inside other top-level functions — 'CaptureClosure'
by construction — and saturated call sites of top-level lambdas are
already served by the call-site inliner ('inlineSaturatedCall').

Left for the follow-up analyses that need them: per-use-kind counters
(call/access/case) and an admission for a projection used only in call
position.
-}

-- See Note [Inline annotations and inlining heuristics]
-- and Note [Complexity and Capture gate inlining]
isInlinableExpr ∷ Exp → Bool
isInlinableExpr expr = hasInlineAnnotation expr || isInlinableValue expr
 where
  hasInlineAnnotation ∷ Exp → Bool
  hasInlineAnnotation =
    getAnn >>> \case
      Just Always → True
      _ → False

{- | The structural tiers of 'isInlinableExpr' — everything but the
Always annotation, which the top-level inliner consults by name instead
(see 'InlinePolicy' and issue #171).
-}
isInlinableValue ∷ Exp → Bool
isInlinableValue expr =
  isRef expr
    || isNonRecursiveLiteral expr
    || isCheapProjection expr
 where
  isRef ∷ RawExp a → Bool
  isRef = \case
    Ref {} → True
    _ → False

  -- The Deref tier. The explicit disjuncts above are subsumed for the
  -- shapes they share (a Ref, a short scalar), but kept: they also admit
  -- what the tier prices differently (a long string literal).
  isCheapProjection ∷ Exp → Bool
  isCheapProjection e =
    complexityOf e <= Deref && expSize e < smallInlineBudget

{- | The KnownSize tier of Note [Complexity and Capture gate inlining]:
a small closed abstraction whose bound name is only used outside
branches and closures may be pasted at every use site.
-}
isDuplicatableClosedAbs ∷ Exp → Usage → Bool
isDuplicatableClosedAbs rhs Usage {usageCapture} =
  isAbs rhs
    && usageCapture == CaptureNone
    && expSize rhs < smallInlineBudget
    && isClosedExp rhs
 where
  isAbs ∷ RawExp a → Bool
  isAbs = \case
    AbsN {} → True
    _ → False

{- | No free local references. Imported references do not count: they
are valid at any position in the module, so they survive being
pasted anywhere.
-}
isClosedExp ∷ RawExp ann → Bool
isClosedExp =
  not . any isLocalName . Map.keys . countFreeRefs
 where
  isLocalName ∷ Qualified Name → Bool
  isLocalName = \case
    Local _ → True
    _ → False
