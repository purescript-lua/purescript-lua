module Language.PureScript.Backend.IR.Optimizer where

import Control.Lens (over, toListOf, transformOf, universeOf)
import Control.Monad.Writer.CPS (WriterT, runWriterT, tell)
import Data.Char (isAscii)
import Data.Foldable (foldrM)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Map qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import GHC.Generics (Generically (..))
import Language.PureScript.Backend.IR.CSE (eliminateCommonSubexpressions)
import Language.PureScript.Backend.IR.Cpr (cprWorkerWrapper)
import Language.PureScript.Backend.IR.DCE (eliminateDeadCode)
import Language.PureScript.Backend.IR.EffectNames
  ( canonicalizeEffectAppInModule
  )
import Language.PureScript.Backend.IR.FlattenDeepBinds (flattenDeepBindsM)
import Language.PureScript.Backend.IR.FloatIn (floatIn)
import Language.PureScript.Backend.IR.Inliner (Annotation (..))
import Language.PureScript.Backend.IR.Linker
  ( UberModule (..)
  , foreignAccessorQName
  )
import Language.PureScript.Backend.IR.MagicDo (magicDo)
import Language.PureScript.Backend.IR.Names
  ( ModuleName
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
import Language.PureScript.Backend.IR.Query
  ( CtorShape (..)
  , ctorShapeTag
  , resolveKnownCtorApp
  )
import Language.PureScript.Backend.IR.Query qualified as Query
import Language.PureScript.Backend.IR.RecordSurgery (foldRecordSurgery)
import Language.PureScript.Backend.IR.SpecConstr (specConstr)
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName, runSupply)
import Language.PureScript.Backend.IR.Types
  ( AlgebraicType (SumType)
  , Ann
  , Capture (..)
  , DataTypes
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
  , expSize
  , freshenBinders
  , getAnn
  , isEffectRun
  , isForeignImport
  , isLiteral
  , isNonRecursiveLiteral
  , lets
  , listGrouping
  , literalBool
  , literalFloat
  , literalInt
  , literalString
  , noAnn
  , paramName
  , primBinOp
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

optimizedUberModule ∷ DataTypes → UberModule → UberModule
optimizedUberModule dataTypes uber = runSupply do
  let policy = collectInlinePolicy uber
  settled ← runSteps (settlePhase (optimizerPipeline dataTypes policy)) uber
  -- See Note [Derived inline directives]
  let extended = policy <> derivedInlinePolicy policy settled
  runSteps (lowerPhase (optimizerPipeline dataTypes extended)) settled

{- | 'optimizedUberModule' with every pass's contract checked by the
linter, failing with the name of the offending pass. Used by the test
suite always, and by the CLI behind the @--lint-ir@ flag.
-}
optimizedUberModuleChecked
  ∷ DataTypes → UberModule → Either PassCheckFailure UberModule
optimizedUberModuleChecked dataTypes uber = runSupply $ runExceptT do
  let policy = collectInlinePolicy uber
  settled ←
    ExceptT
      (runStepsChecked (settlePhase (optimizerPipeline dataTypes policy)) uber)
  -- See Note [Derived inline directives]
  let extended = policy <> derivedInlinePolicy policy settled
  ExceptT
    (runStepsChecked (lowerPhase (optimizerPipeline dataTypes extended)) settled)

{- | The optimizer pipeline, split at the directive-derivation point:
the settle phase brings every binding to the shape
'derivedInlinePolicy' reads, and the lower phase consumes the extended
policy. See Note [Derived inline directives] for why the split falls
exactly there.
-}
data OptimizerPhases = OptimizerPhases
  { settlePhase ∷ [Step]
  , lowerPhase ∷ [Step]
  }

{- | The IR optimization pipeline. The first argument is the data-type
table collected from CoreFn ('collectDataDeclarations'), consulted by
the exhaustiveness-driven rewrite ('removeUnreachableMatchDefault');
the second is the inlining policy collected once from the pristine
module before any pass runs: later rewrites may strip annotations, so
every directive keys off a name (see Note [Inline annotations and
inlining heuristics]). The result is phase-split so the caller can
extend the policy with derived directives between the phases
('OptimizerPhases').
-}
optimizerPipeline ∷ DataTypes → InlinePolicy → OptimizerPhases
optimizerPipeline dataTypes policy = OptimizerPhases {settlePhase, lowerPhase}
 where
  settlePhase =
    [ -- The entry pass (issue #139): establishes the global-uniqueness
      -- condition (GUC = 'UniqueBinders') that every
      -- following pass requires and preserves.
      RunPass uniquifyPass
    , RunFixpoint "optimize+dce" (optimizePass :| [dcePass])
    , -- by merging foreign bindings into the main bindings, we can
      -- unblock even more optimizations, e.g. inline foreign bindings.
      RunPass mergeForeignsPass
    , RunFixpoint "optimize+dce-post-merge" (optimizePass :| [dcePass])
    ]
  lowerPhase =
    [ -- Split curried bindings into n-ary workers and curried wrappers
      -- and rewrite the saturated call sites to direct worker calls
      -- (issue #24) — the early of the pass's two runs (the late one
      -- closes the pipeline). Runs after the post-merge fixpoint, so
      -- manifest arities are measured once inlining has settled. See
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
    , -- Magic-do (issue #46) recognises Effect/ST chains by their canonical
      -- heads (Note [Canonical Effect/ST heads]) and relies on the unique
      -- naming established by 'uniquifyNames', which it preserves. It runs
      -- after the optimize fixpoints so dissolution has exposed the
      -- canonical heads at the use sites; the `local _ =` statements it
      -- introduces for `discard` are effect runs, which the passes that
      -- follow leave alone (see 'isEffectRun'). See
      -- Language.PureScript.Backend.IR.MagicDo.
      RunPass magicDoPass
    , -- Budgeted call-site inlining of dictionary methods (issue #180), the
      -- cure for non-Effect/ST monadic chains that compile to nested closure
      -- chains. Runs only here, after magicDo has lowered the Effect/ST chains:
      -- inlining a bind before that would leave magicDo a chain it can no
      -- longer recognise. The inlined methods' constructor matches then meet
      -- the case-of-known-constructor folds (#177/#213/#214), collapsing
      -- Maybe/Either/Writer/State chains into straight-line code. Code growth
      -- is bounded per paste by 'inlineSizeBudget' and per expression by the
      -- growth veto (Note [Bounded call-site inlining growth]), which keeps
      -- a chain whose pastes never collapse from unrolling.
      --
      -- Call-pattern specialization (issue #208) rides in the same fixpoint:
      -- a recursive binding whose recursion passes a known constructor at a
      -- scrutinized parameter position gets an unboxed specialized copy, and
      -- the next optimize round's constructor folds collapse the reboxes its
      -- body carries. Each round mints one specialization layer, so the
      -- fixpoint provides the bounded iteration a nested accumulator needs;
      -- the per-binding cap in Language.PureScript.Backend.IR.SpecConstr
      -- keeps the minting finite.
      RunFixpoint "specialize+dce" (specializePass :| [dcePass, specConstrPass])
    , -- CPR worker/wrapper on results (issue #206): split every binding
      -- whose every return path builds one fixed saturated constructor
      -- into a worker returning the fields as Lua multiple values plus a
      -- rebox wrapper, rewriting the let-bound deconstructing sites to
      -- direct worker calls behind an in-place rebox. Runs after the
      -- specialize fixpoint — the monadic chains are collapsed and the
      -- call-pattern specializations are minted, so the constructor-tailed
      -- candidates and their deconstructing sites are maximal — and before
      -- shareAccessors/cse/flattenDeepBinds, which must tolerate, but never
      -- create, the Values/LetValues nodes. See
      -- Language.PureScript.Backend.IR.Cpr.
      RunPass cprPass
    , -- Cancel the reboxes the split planted: floatLetValuesFromLetRhs
      -- surfaces each one as a let-bound constructor, where the
      -- known-constructor folds meet the site's eliminating reads and
      -- the product dissolves; dce then drops the wrappers whose every
      -- site went to the worker directly. Same members as the fixpoint
      -- above, so call-pattern specialization keeps firing on shapes the
      -- cancellation exposes.
      RunFixpoint
        "specialize+dce-post-cpr"
        (specializePass :| [dcePass, specConstrPass])
    , -- Rebuild sharing for the foreign-accessor reads that dissolution
      -- and the call-site pastes above duplicated: a read surviving at
      -- two or more sites is re-bound to its linker name, which stage-2
      -- promotion then turns into a chunk local (issue #248). Runs after
      -- the last pass that can multiply reads and before the final
      -- flattening. See 'shareForeignAccessors'.
      RunPass shareAccessorsPass
    , -- Rebuild sharing within one body for the pure repeats the pastes
      -- above left behind (issue #183): alpha-equivalent effect-free
      -- subexpressions of a block are hoisted into a shared Let. Runs
      -- after the last duplicating pass and after share-accessors (so
      -- accessor reads are already references to top-level names, not
      -- grabbed per body here), and outside any fixpoint: the Deref tier
      -- of inlineLocalBindings would paste hoisted projections straight
      -- back. See Language.PureScript.Backend.IR.CSE.
      RunPass csePass
    , -- Flatten the remaining deeply-nested expression trees (issues #104,
      -- #108): continuation/bind chains of any monad (lambda-lifted
      -- into $kont helpers) and applicative/flipped-bind application
      -- spines (A-normalised into $tmp locals). Runs after magicDo (which
      -- consumes Effect/ST chains, leaving only non-Effect/ST ones) and
      -- likewise consumes and preserves the unique naming.
      -- See Language.PureScript.Backend.IR.FlattenDeepBinds.
      RunPass flattenDeepBindsPass
    , -- The late uncurry run (issue #200): the same pass again, now that
      -- the two saturated-site families invisible to the early run exist —
      -- the effect-run spines magicDo completed (f(a)(b)(run), saturating
      -- the effect function's manifest chain, thunk parameter included)
      -- and the saturated-by-construction $kont helpers minted by the
      -- flattening above. Bindings the early run split are recognised and
      -- left split (see the Rerun section in
      -- Language.PureScript.Backend.IR.Uncurry).
      RunPass uncurryLatePass
    , -- Drop the wrappers the late run left unreferenced. A single dce
      -- pass, deliberately not an optimize+dce fixpoint like the early
      -- run's: optimize's use-once inlining would paste the $kont workers
      -- (each is called exactly once) back into their call sites round by
      -- round, re-nesting exactly what flattenDeepBinds just flattened.
      RunPass dcePass
    ]
  ctorTags ∷ CtorTagSets
  ctorTags = ctorTagSets dataTypes

  uniquifyPass =
    Pass
      { passName = "uniquify"
      , passRun = conservatively . pure . uniquifyNames
      , passRequires = wellScoped
      , passEnsures = guc
      }
  -- The pre-magicDo optimize pass does no call-site inlining (issue
  -- #180). MagicDo's name-keyed recognition (issue #182) does not
  -- depend on it — the canonical heads are foreigns no call-site paste
  -- can dismantle — so the skip is conservative caution against
  -- reshaping the chains before they are lowered; flipping it is
  -- follow-up work.
  optimizePass =
    Pass
      { passName = "optimize"
      , passRun = optimizeModule ctorTags SkipCallSites policy
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
      , passRun = optimizeModule ctorTags InlineCallSites policy
      , passRequires = guc
      , passEnsures = guc
      }
  specConstrPass =
    Pass
      { passName = "spec-constr"
      , passRun = specConstr (uncurryVeto policy)
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
  uncurryLatePass = uncurryPass {passName = "uncurry-late"}
  -- The veto is shared with the uncurrying pass: both splits hide a
  -- name's call sites from the name-keyed inline policies.
  cprPass =
    Pass
      { passName = "cpr"
      , passRun = cprWorkerWrapper (uncurryVeto policy)
      , passRequires = guc
      , passEnsures = guc
      }
  floatInPass = gucPass "float-in" floatIn
  shareAccessorsPass =
    gucPass "share-accessors" (shareForeignAccessors policy)
  csePass =
    Pass
      { passName = "cse"
      , passRun =
          conservatively . eliminateCommonSubexpressions (policyAlways policy)
      , passRequires = guc
      , passEnsures = guc
      }
  magicDoPass = gucPass "magicDo" magicDo
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
'optimizerPipeline'). The @inline@ directive is consulted by name, from
the same 'InlinePolicy' every other inlining decision reads: a name
under @inline always@ is skipped — its read is pasted per site on
explicit request — and a @never@ accessor never dissolved in the first
place, so its reads are already references to the kept binding (see
Note [Inline annotations and inlining heuristics]). The read nodes
themselves carry no directive weight here: a paste sheds the root
annotation ('withBinding'), and a fold can transplant or drop one
mid-pipeline. The re-bound
accessor is inserted right after its module's 'ForeignImport' binding,
where the module-init order guarantees the foreign table is already
initialized; the reads it replaces sit in bindings placed after every
foreign table ('mergeForeignsIntoBindings' front-loads them all) or in
exports.
-}
shareForeignAccessors ∷ InlinePolicy → UberModule → UberModule
shareForeignAccessors policy uber
  | Map.null shared = uber
  | otherwise =
      uber
        { uberModuleBindings =
            insertAccessorBindings
              (fmap (fmap (fmap rewriteExp)) uberModuleBindings)
        , uberModuleExports = fmap (fmap rewriteExp) uberModuleExports
        }
 where
  UberModule {uberModuleBindings, uberModuleExports} = uber

  -- Accessor reads of names with no @inline always@ directive, keyed
  -- by the QName the linker originally bound the accessor to, with one
  -- representative expression per key (copies are identical up to
  -- their annotation slot, normalized to 'Nothing' here). Only reads
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
          Map.fromListWith
            (+)
            [(qname, 1 ∷ Natural) | (qname, _) ← accessorReads]

  accessorReads ∷ [(QName, Exp)]
  accessorReads =
    [ (qname, setAnn Nothing node)
    | expr ←
        (snd <$> (listGrouping =<< uberModuleBindings))
          <> (snd <$> uberModuleExports)
    , node ← universeOf subexpressions expr
    , Just qname ← [foreignAccessorQName node]
    , qname `Set.notMember` policyAlways policy
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
        | qname `Map.member` shared →
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

{- Note [Derived inline directives]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A specialization binding names a directive-carrying combinator without
carrying a directive of its own: purs's common-subexpression pass
floats a repeated dictionary application to a top-level binding like
@bind = Control.Bind.bind bindStateT@, and a user writes the same shape
by hand as a top-level partial application. Annotating each such
binding is busywork the compiler can do itself, because the Arity
policy composes over application. Let @f@ carry @arity=N@ and let
@a = f x₁ … xₖ@:

  * k < N: a site applying @N − k@ more arguments to @a@ becomes, once
    @a@'s right-hand side is pasted there, a site applying at least N
    arguments to @f@ — exactly a qualifying site of the directive. So
    @a@ inherits @arity=(N − k)@.
  * k ≥ N: the right-hand side is itself already a qualifying call of
    @f@, so every use of @a@ stands for the specialized value and the
    binding inherits always-inline — the @arity=0@ reading of the same
    arithmetic.

Pasting a partial application re-evaluates its argument expressions per
site. At a user-marked call site ('inlineSaturatedCall') the explicit
directive on the target licenses that duplication, but a derived
directive is compiler-initiated: the derivation fires only when every
applied argument is a value, work-free to repeat — a reference, a
literal (a settled dictionary literal is the winning shape: its
per-site copy meets the constructor folds and vanishes), or a lambda.
A computed argument — say a dictionary built by applying a
transformer's instance function — keeps the specialization a shared
binding instead of re-running the computation per site.

The derivation reads the module settled by the post-merge optimize+dce
fixpoint ('settlePhase'), not the pristine input: a specialization
referenced once has already dissolved into its use site — deriving for
it would only pin what the use-once path inlines wholesale — and the
survivors carry their final shapes. It runs before the uncurry split,
so a derived arity joins 'uncurryVeto' like an explicit one, and
before the post-uncurry optimize+dce fixpoint, whose whole-binding
inlining ('withBinding') performs the always-inline pastes the
derivation emits; derived arities paste at qualifying call sites in
the specialize fixpoint exactly like explicit ones.

One left-to-right fold derives transitively and bounds the work: a
standalone binding references only earlier bindings (the order
'withBinding' relies on), so a chain of specializations meets each
target's — possibly itself derived — arity before the alias naming it
is visited, and every binding is inspected exactly once. Only the
Arity policy seeds derivation: an @always@ target's bare-Ref alias is
deliberately kept as its materialization point (issue #171), and a
@never@ target needs no propagation — its own veto already covers
every site. An explicit root directive on a specialization is never
overridden.
-}

{- | The directives derived from the settled shapes of specialization
bindings — the extension only, disjoint from the explicit policy it is
derived against and combined with by the caller.
See Note [Derived inline directives].
-}
derivedInlinePolicy ∷ InlinePolicy → UberModule → InlinePolicy
derivedInlinePolicy explicit UberModule {uberModuleBindings} =
  foldl' derive mempty uberModuleBindings
 where
  derive ∷ InlinePolicy → Grouping (QName, Exp) → InlinePolicy
  derive derived = \case
    Standalone (qname, expr)
      | not (hasRootDirective qname)
      , (Ref _ headName, args@(_ : _)) ← unwindApp expr
      , all workFreeToRepeat args
      , Just target ← refQName headName
      , Just arity ←
          Map.lookup target (policyArity explicit)
            <|> Map.lookup target (policyArity derived) →
          derived <> case fromIntegral (length args) of
            applied
              | applied >= arity →
                  mempty {policyAlways = Set.singleton qname}
              | otherwise →
                  mempty {policyArity = Map.singleton qname (arity - applied)}
    _ → derived

  -- Pasting re-evaluates the applied arguments per site; see
  -- Note [Derived inline directives] for why the derivation requires
  -- them work-free while a user-marked site does not. Values qualify
  -- (references, literals, lambdas — a settled dictionary literal
  -- argument is the winning shape, its per-site copy folds away);
  -- anything that computes (an application, a case, a let) does not.
  workFreeToRepeat ∷ Exp → Bool
  workFreeToRepeat = \case
    Ref {} → True
    LiteralInt {} → True
    LiteralFloat {} → True
    LiteralString {} → True
    LiteralChar {} → True
    LiteralBool {} → True
    LiteralArray _ elems → all workFreeToRepeat elems
    LiteralObject _ props → all (workFreeToRepeat . snd) props
    AbsN {} → True
    _ → False

  hasRootDirective ∷ QName → Bool
  hasRootDirective qname =
    qname `Set.member` policyAlways explicit
      || qname `Set.member` policyNever explicit
      || qname `Map.member` policyArity explicit

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
  ∷ CtorTagSets
  → CallSiteInlining
  → InlinePolicy
  → UberModule
  → SupplyM (UberModule, WasRewritten)
optimizeModule ctorTags inlining policy UberModule {..} = runWriterT do
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
  -- pre-magicDo runs, which keep the Effect/ST chains unreshaped until
  -- magicDo lowers them (see 'optimizerPipeline').
  inlineEnv ∷ InlineEnv
  inlineEnv = case inlining of
    SkipCallSites → mempty
    InlineCallSites →
      Map.fromList
        [ (qualifiedQName qname, expr)
        | Standalone (qname, expr) ← uberModuleBindings
        , qname `Set.notMember` policyNever policy
        ]

  -- Top-level bindings the Effect/ST canonicalization may resolve
  -- aliases through and manufacture references into (issue #297; see
  -- 'canonicalizeEffectHead'). Unlike 'inlineEnv' it is unconditional —
  -- canonicalization must complete in the pre-magicDo runs — and it
  -- includes the foreigns, which hold the canonical accessor bindings
  -- until 'mergeForeigns' folds them into the main bindings. A by-value
  -- snapshot: resolution only reads right-hand sides, and a reference
  -- manufactured into a binding this run later drops is substituted
  -- away with the binding's other use sites ('withBinding'), so
  -- staleness cannot dangle.
  canonEnv ∷ CanonEnv
  canonEnv =
    Map.fromList $
      [(qname, expr) | Standalone (qname, expr) ← uberModuleBindings]
        <> uberModuleForeigns

  -- An @inline never@ name may not be pasted at all; an @inline arity=N@
  -- name is pasted only at qualifying call sites — pasting the whole
  -- binding would reach under-applied sites too.
  vetoedWholeBinding ∷ QName → Bool
  vetoedWholeBinding qname =
    qname `Set.member` policyNever policy
      || qname `Map.member` policyArity policy

  -- The top-level counterpart of 'isInlinableExpr', diverging from it
  -- twice (issue #171). The Always directive is consulted by name —
  -- 'policyAlways', never the RHS root annotation — for the reason all
  -- directives are ('collectInlinePolicy'): a rewrite can drop or
  -- transplant a live node's annotation, and the whole-binding paste
  -- sheds it outright (see 'withBinding'). And a bare-Ref alias to an
  -- @inline always@ binding is never dissolved: substituting it would
  -- multiply the target's use sites right before Always pastes its
  -- body into every one of them, destroying the alias that is the
  -- better materialization point on both size and speed. The target's
  -- body pastes into the surviving alias instead.
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
  optimizeExp e = case inlining of
    SkipCallSites → keepSweep HeuristicPastes
    InlineCallSites → speculativeSweep HeuristicPastes
   where
    -- An armed sweep is speculative: kept only while the pastes' growth
    -- stays within the expression's allowance; a sweep that grew
    -- without collapse is discarded — result and change flag both — and
    -- redone one rung down: first with the n-ary worker tier disarmed,
    -- then with every heuristic tier disarmed.
    -- See Note [Bounded call-site inlining growth].
    speculativeSweep ∷ CallSitePastes → WriterT WasRewritten SupplyM Exp
    speculativeSweep pastes = do
      (e', rewritten) ←
        lift $
          optimizedExpressionWithPastes
            ctorTags
            canonEnv
            pastes
            policy
            inlineEnv
            e
      if expSize e' <= inlineGrowthBudget (expSize e)
        then e' <$ tell rewritten
        else case pastes of
          HeuristicPastes → speculativeSweep CurriedPastesOnly
          _ → keepSweep DirectedPastesOnly

    keepSweep ∷ CallSitePastes → WriterT WasRewritten SupplyM Exp
    keepSweep pastes = do
      (e', rewritten) ←
        lift
          ( optimizedExpressionWithPastes
              ctorTags
              canonEnv
              pastes
              policy
              inlineEnv
              e
          )
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
            -- The pasted copies are no longer the directed binding, so
            -- the root annotation is spent at the paste rather than
            -- riding into the hosts (mirrors the call-site paste in
            -- 'inlineSaturatedCall'): an @inline always@ body pasted
            -- into a bare-Ref alias would otherwise plant Just Always
            -- on the alias's root, turning the alias itself
            -- unconditionally inlinable one round later (issue #171).
            let pasted = setAnn Nothing expr
            (bindings', exports') ←
              lift $
                (,)
                  <$> substituteInBindings qname pasted bindings
                  <*> substituteInExports qname pasted exports
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

{- | Top-level bindings visible to the Effect/ST canonicalization
('canonicalizeEffectHead'): alias resolution reads their right-hand
sides, and a canonical reference is manufactured only for a name the
map still holds (issue #297). Built per 'optimizeModule' run from the
'Standalone' bindings plus the foreigns.
-}
type CanonEnv = Map QName Exp

{- | For every sum-type constructor tag ('ctorId'), the complete tag set
of the type declaring it — the exhaustiveness oracle of
'removeUnreachableMatchDefault'. Built once per pipeline
('optimizerPipeline') from the declared data types, so membership is
exact: a tag chain covering its type's whole set proves the synthesized
match default unreachable. Product types are omitted — their matches
emit no tag tests (see 'Language.PureScript.Backend.IR.mkCaseClauses').
-}
type CtorTagSets = Map Text (Set Text)

ctorTagSets ∷ DataTypes → CtorTagSets
ctorTagSets dataTypes =
  Map.fromList
    [ (tag, tags)
    | ((modName, tyName), (SumType, ctors)) ← Map.toList dataTypes
    , let tags =
            Set.fromList
              [ctorId modName tyName ctorName | ctorName ← Map.keys ctors]
    , tag ← toList tags
    ]

{- | The largest expression the call-site inliner will paste, GHC's
unfolding-use-threshold analogue, sized in IR nodes ('expSize'). Code
growth is the transform's main risk (issue #180); this bounds one
paste, and the growth veto bounds their sum across an expression
(Note [Bounded call-site inlining growth]). Deliberately generous
enough to admit an uncurried monad-method worker (a folded Maybe/Either
match), the payload the cascade is built to collapse.
-}
inlineSizeBudget ∷ Natural
inlineSizeBudget = 64

{- | The largest expression the Deref and KnownSize inlining tiers
paste (Note [Complexity and Capture gate inlining]), sized in IR nodes
like 'inlineSizeBudget' but far below it: these admissions duplicate at
every use site, so growth scales with the use count.
-}
smallInlineBudget ∷ Natural
smallInlineBudget = 16

{- Note [Bounded call-site inlining growth]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Call-site pastes are bets: pasting a method body pays off when the copy
meets a known-constructor fold and collapses (a Maybe/Either match
dissolves into straight-line code), and loses when nothing folds (a
product-type monad such as State threads a single-constructor Tuple —
no tag test exists, so the pasted bodies just accumulate, issue #221).
Whether a paste collapses is not knowable at the paste site: the fold
may need several other pastes and reductions to expose a known
constructor, all of which happen later in the same bottom-up sweep. The
per-paste budgets bound each site's bet, but not the sum of bets across
an expression: a long chain pastes one body per step, and when none of
them folds the expression grows linearly in the chain length.

So the sweep is speculative, measured, and reverted at expression
granularity ('optimizeExp'): run the rewrite with every paste tier
armed, compare 'expSize' before and after, and when the result grew
past 'inlineGrowthBudget' — growth without collapse — discard it,
result and change flag both, and redo the sweep one rung down. The
first fallback rung ('CurriedPastesOnly') disarms only the n-ary worker
tier, the most speculative pastes (an uncurried worker's body often has
nothing at the site to fold into): without this rung, worker pastes
that alone overrun the allowance would drag the collapsing pastes at
curried spines — the dictionary-method cascade — down with them in the
all-or-nothing revert. Only when the curried tiers still overrun does
the sweep fall to 'DirectedPastesOnly', every heuristic tier disarmed.
Explicit @inline@ directives keep firing in the fallback sweeps: a
directive is the user overriding the heuristics, so the growth bound
never vetoes it. The env-reading folds ('reduceKnownCtorRefRead',
'propagateKnownCtorThroughLet') also keep firing: they only shrink, and
disarming them would make the fallback sweep strictly worse than the
sweep it replaces.

The allowance is linear with a floor: @before + max smallInlineBudget
(before `div` 4)@. A paste that collapses leaves little residue — the
Maybe match folds to the continuation's body — so the floor only needs
to admit that residue in a small host, and 'smallInlineBudget' already
prices what is free to leave at a site. A paste surviving whole past
that floor is refused even alone in a small host — which is the point,
not a casualty.

The proportional term is calibrated from both sides of the corpus. It
must reject the chains where every paste survives — the transformer
stack of Golden.LongStackBind grows past a third of its host, well
over the quarter. And it must stay above the /transient/ growth of a
collapse that spans fixpoint rounds: the veto measures one sweep, but
an Either chain first grows when its binds paste and only folds a
round later, once the env carries the settled neighbours — measured
just under a fifth of the host on Golden.LongEitherBind. A dial below
that freezes the chain at its unfolded worst (vetoed every round, the
fold never arrives). A quarter clears the one and rejects the other.
The blind spot of the dial is many tiny pastes diluted in a huge host
(the plain State chain of Golden.LongStateBind grows only ~10% in
nodes, though far more in printed lines); catching it needs the
measurement at fixpoint convergence rather than per sweep, where
transient growth is invisible and the dial could drop.

The measurement baseline resets each round of the specialize fixpoint,
which is what makes the veto safe and non-sticky. Reverting to the
round's own input can never dangle a reference: that input is live this
round, and DCE runs after. An expression vetoed in round N is
re-attempted in round N+1 against the then-current environment, so a
collapse unlocked by a neighbour's settled form still lands; one that
needs the kept pastes themselves does not get that chance, which is
what the transient-growth calibration above accounts for. The
discarded sweep never reports 'Rewritten', so a converged module still
reports 'Unmodified' and the fixpoint terminates ('runStepsChecked'
enforces exactly this contract). The cost is one extra sweep per vetoed
expression per 'optimizeExp' call.
-}

{- | Which call-site paste tiers a rewrite sweep may use: all of them;
the heuristic tiers at curried spines only, with the n-ary worker tier
disarmed; or only those an explicit @inline@ directive commands. The
growth veto falls back one rung at a time.
See Note [Bounded call-site inlining growth].
-}
data CallSitePastes
  = HeuristicPastes
  | CurriedPastesOnly
  | DirectedPastesOnly
  deriving stock (Eq)

{- | Per-expression growth allowance for one call-site inlining sweep:
the largest 'expSize' the sweep may leave behind, given the size it
started from. See Note [Bounded call-site inlining growth].
-}
inlineGrowthBudget ∷ Natural → Natural
inlineGrowthBudget before = before + max smallInlineBudget (before `div` 4)

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
Trivial base — pasted at any use count, which for the length read is what
obliges 'PrimLen' to keep its operand immutable (see Note [PrimLen reads
immutable values]). 'KnownSize': an abstraction or a non-empty literal — a
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
  PrimLen _ann base → Deref <> complexityOf base
  ReflectCtor _ann base → Deref <> complexityOf base
  DataArgumentByIndex _ann _algTy _idx base → Deref <> complexityOf base
  AbsN _ann _params body → KnownSize <> complexityOf body
  -- A 'Ctor' is a table allocation, so it stays 'NonTrivial' rather than
  -- folding its fields in as a bounded 'KnownSize' literal would: that keeps
  -- a nullary singleton (@Ctor []@) shared through a binding instead of
  -- re-allocated at every use site. See Note [Constructor applications are
  -- saturated].
  Ctor {} → NonTrivial
  -- The multi-value nodes are position-restricted (Note [Multi-value
  -- results]): duplicating them into argument positions is never
  -- admissible, so both are explicitly 'NonTrivial'.
  Values {} → NonTrivial
  LetValues {} → NonTrivial
  _ → NonTrivial

{- | Pure wrapper for tests and standalone use: runs the rewrite with
its own supply, no inlining environment, no top-level bindings and no
data-type table. Production code uses 'optimizedExpressionM' so all
passes share one supply.
-}
optimizedExpression ∷ Exp → Exp
optimizedExpression =
  runSupply . fmap fst . optimizedExpressionM mempty mempty mempty mempty

{- | 'optimizedExpression' with data-type declarations in scope, so the
exhaustiveness-driven rewrite can consult declared constructor sets
(see 'removeUnreachableMatchDefault').
-}
optimizedExpressionWithTypes ∷ DataTypes → Exp → Exp
optimizedExpressionWithTypes dataTypes =
  runSupply
    . fmap fst
    . optimizedExpressionM (ctorTagSets dataTypes) mempty mempty mempty

{- | 'optimizedExpression' with top-level bindings visible to the
Effect/ST canonicalization ('canonicalizeEffectHead'), for tests
exercising that rule: it only manufactures references the environment
can still resolve.
-}
optimizedExpressionWithCanon ∷ CanonEnv → Exp → Exp
optimizedExpressionWithCanon canon =
  runSupply . fmap fst . optimizedExpressionM mempty canon mempty mempty

optimizedExpressionM
  ∷ CtorTagSets
  → CanonEnv
  → InlinePolicy
  → InlineEnv
  → Exp
  → SupplyM (Exp, WasRewritten)
optimizedExpressionM ctorTags canon =
  optimizedExpressionWithPastes ctorTags canon HeuristicPastes

optimizedExpressionWithPastes
  ∷ CtorTagSets
  → CanonEnv
  → CallSitePastes
  → InlinePolicy
  → InlineEnv
  → Exp
  → SupplyM (Exp, WasRewritten)
optimizedExpressionWithPastes ctorTags canon pastes policy env =
  -- See Note [Eta reduction is unsound]
  rewriteExpBottomUpM
    ( canonicalizeEffectHead canon
        `thenRewrite` constantFolding
        `thenRewrite` reassociateConstants
        `thenRewrite` foldRecordSurgery
        `thenRewrite` reduceObjectProp
        `thenRewrite` reduceObjectUpdate
        `thenRewrite` reduceArrayRead
        `thenRewrite` sinkProjectionIntoLet
        `thenRewrite` cancelLetValuesOfValues
        `thenRewrite` floatLetFromLetValuesRhs
        `thenRewrite` floatLetValuesFromLetRhs
        `thenRewrite` sinkReadIntoLetValues
        `thenRewrite` reduceKnownConstructor
        `thenRewrite` reduceKnownCtorRefRead env
        `thenRewrite` propagateKnownCtorThroughLet env
        `thenRewrite` propagateKnownArrayThroughLet
        `thenRewrite` propagateKnownObjectThroughLet
        `thenRewrite` propagateObjectUpdateThroughLet
        `thenRewrite` resolveDictionaryProp pastes policy env
        `thenRewrite` inlineAnnotatedProjection policy env
        `thenRewrite` inlineSaturatedCall pastes policy env
        `thenRewrite` betaReduce
        `thenRewrite` removeUnreachableThenBranch
        `thenRewrite` removeUnreachableElseBranch
        `thenRewrite` removeIfWithEqualBranches
        `thenRewrite` propagateKnownCondIntoBranches
        `thenRewrite` removeUnreachableMatchDefault ctorTags
        `thenRewrite` flipNegatedIf
        `thenRewrite` reduceBooleanIf
        `thenRewrite` pushEqIntoIfBranches
        `thenRewrite` pushIfCondIntoBranches
        `thenRewrite` pushEliminatorIntoIfBranches
        `thenRewrite` inlineLocalBindings
    )

{- | Tier 2 of Note [Canonical Effect/ST heads]: rewrite an Effect/ST
dictionary application into a reference to the real foreign method. The
translation tier cannot see a dictionary reference that is 'Local'
inside its defining module — it only becomes 'Imported' once the
linker requalifies it — and alias dissolution can expose further pairs
mid-pipeline. The 'CanonEnv' lets the rule match heads hidden behind
top-level aliases (the purs CSE floats of issue #297) and stops it from
manufacturing a reference to an accessor binding the module no longer
has. Strictly shrinking (two nodes to one), so fixpoint-safe.
-}
canonicalizeEffectHead ∷ Applicative m ⇒ CanonEnv → RewriteRuleM m Ann
canonicalizeEffectHead canon = pure . canonicalizeEffectAppInModule canon

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
    Eq _ a b
      | Just result ← foldEqLiterals a b →
          Just $ literalBool result
    -- The other operand must be of type Bool in each of the four cases
    -- below; see Note [IR is assumed well-typed]. A false literal folds
    -- to the negation (issue #223) — the shape a Boolean pattern match
    -- re-tests its scrutinee with (@false == a@).
    Eq _ (LiteralBool _ True) b →
      Just b
    Eq _ b (LiteralBool _ True) →
      Just b
    Eq _ (LiteralBool _ False) b →
      Just (primNot b)
    Eq _ b (LiteralBool _ False) →
      Just (primNot b)
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
  * Comparisons fold on two numbers (int or finite float), and on two
    ASCII chars, whose single-byte Lua representation orders exactly
    like the codepoint. Strings and non-ASCII chars are left alone,
    because Lua orders strings by bytes while the IR literal carries
    semantic 'Text'.
  * @and@/@or@ fold when both operands are boolean, and additionally
    collapse a known-boolean first operand (@true and b == b@,
    @false or b == b@, and the two annihilators): sound because Lua
    @and@/@or@ short-circuit, so dropping the second operand is exactly
    what the runtime does. An identity /second/ operand (@a and true@,
    @a or false@) also folds to @a@ — nothing is skipped, and the
    literal cannot change a boolean @a@'s value (see Note [IR is
    assumed well-typed]). The annihilator duals (@a and false@,
    @a or true@) are left to the runtime, since folding them would skip
    @a@'s evaluation.
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
  (PrimLt, _, _) → literalBool . (== LT) <$> compareLiterals l r
  (PrimLe, _, _) → literalBool . (/= GT) <$> compareLiterals l r
  (PrimGt, _, _) → literalBool . (== GT) <$> compareLiterals l r
  (PrimGe, _, _) → literalBool . (/= LT) <$> compareLiterals l r
  (PrimAnd, LiteralBool _ a, LiteralBool _ b) → Just (literalBool (a && b))
  (PrimAnd, LiteralBool _ True, b) → Just b
  (PrimAnd, LiteralBool _ False, _) → Just (literalBool False)
  (PrimAnd, a, LiteralBool _ True) → Just a
  (PrimOr, LiteralBool _ a, LiteralBool _ b) → Just (literalBool (a || b))
  (PrimOr, LiteralBool _ True, _) → Just (literalBool True)
  (PrimOr, LiteralBool _ False, b) → Just b
  (PrimOr, a, LiteralBool _ False) → Just a
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

  compareLiterals ∷ Exp → Exp → Maybe Ordering
  compareLiterals a b = case (a, b) of
    (LiteralInt _ x, LiteralInt _ y) → Just (compare x y)
    (LiteralFloat _ x, LiteralFloat _ y)
      | isFinite x, isFinite y → Just (compare x y)
    (LiteralChar _ x, LiteralChar _ y)
      | isAscii x, isAscii y → Just (compare x y)
    _ → Nothing

  isFinite ∷ Double → Bool
  isFinite d = not (isNaN d || isInfinite d)

{- | Fold logical @not@ over a boolean literal, eliminate a double
negation (@not (not e)@ ⟶ @e@, sound since @e@ is a 'Bool'), and push
@not@ through an ordering comparison to its complement
(@not (a < b)@ ⟶ @a >= b@, issue #238). See Note [IR primops].

The complement flip is exact iff Lua orders the compared domain
totally, and a literal operand of a NaN-free kind is the witness: an
Int, Char, or String literal pins both operands' type (Note [IR is
assumed well-typed]), Int values are integral doubles, and Lua's
string order is total for any byte content — the flip needs totality
only, so unlike the constant fold it covers non-ASCII chars. A Float
literal is no witness: the other operand can be NaN at runtime, where
every Lua comparison is false — @not (NaN < b)@ is true while Lua's
@NaN >= b@ is false — and the wrapped form is exactly PureScript's
@>=@ on Number, which must be true there (@ordNumberImpl@ maps NaN to
@GT@). Two non-literal operands are likewise unwitnessed and stay
wrapped.
-}
foldPrimNot ∷ Exp → Maybe Exp
foldPrimNot = \case
  LiteralBool _ b → Just (literalBool (not b))
  PrimNot _ e → Just e
  PrimBinOp ann op a b
    | Just flipped ← complementOrdering op
    , isTotalOrderWitness a || isTotalOrderWitness b →
        Just (PrimBinOp ann flipped a b)
  _ → Nothing
 where
  complementOrdering ∷ PrimOp → Maybe PrimOp
  complementOrdering = \case
    PrimLt → Just PrimGe
    PrimLe → Just PrimGt
    PrimGt → Just PrimLe
    PrimGe → Just PrimLt
    _ → Nothing

  isTotalOrderWitness ∷ Exp → Bool
  isTotalOrderWitness = \case
    LiteralInt {} → True
    LiteralChar {} → True
    LiteralString {} → True
    _ → False

{- | Fold an equality of two scalar literals, or 'Nothing' when either
side is not a scalar literal. Two literals of different kinds also
decline: such a comparison is ill-typed input (see Note [IR is assumed
well-typed]), not a provable inequality.
-}
foldEqLiterals ∷ RawExp ann → RawExp ann' → Maybe Bool
foldEqLiterals l r = case (l, r) of
  (LiteralBool _ a, LiteralBool _ b) → Just (a == b)
  (LiteralInt _ a, LiteralInt _ b) → Just (a == b)
  (LiteralFloat _ a, LiteralFloat _ b) → Just (a == b)
  (LiteralChar _ a, LiteralChar _ b) → Just (a == b)
  (LiteralString _ a, LiteralString _ b) → Just (a == b)
  _ → Nothing

{- Note [Reassociating constant chains]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'constantFolding' folds a primop only when both operands are literals,
so a chain like @1 + x + 2 + y + 3@ keeps all three constants apart.
'reassociateConstants' flattens a same-operator tree into its operand
list and coalesces the literal operands into one, for the operators
where reassociation is exact:

  * @+@ and @*@ over Int are associative and commutative: on the ±2^53
    plateau every value is an exact IEEE double and both operations are
    exact integer arithmetic (see Note [Folding primops follows
    Lua 5.1]). All int literals of the spine fold into a single
    constant, appended after the non-literal operands, whose relative
    evaluation order is preserved: @1 + x + 2 + y + 3@ becomes
    @x + y + 6@. The rule declines when any input literal or the
    folded result leaves the plateau — a coalesced literal must be a
    value the runtime holds exactly. It also declines when the spine
    carries a literal of any other kind: a float literal makes it a
    float chain, where IEEE @+@/@*@ are not associative and no
    per-constant guard makes reassociation around a variable sound;
    any other kind is ill-typed input (Note [IR is assumed
    well-typed]).
  * @..@ is associative but not commutative, so only /adjacent/ string
    literals coalesce: @x .. "a" .. "b"@ becomes @x .. "ab"@, while
    @"a" .. x .. "b"@ is left alone. Non-string operands stay in place
    as opaque separators — an FFI-lifted @..@ can hold a number the
    runtime coerces, so they are neither folded nor moved.

A subtree of a different operator is a single opaque operand of the
spine, and constants coalesce around it. @-@/@\/@/@%@ spines are not
associative and never fire; @and@/@or@ short-circuit, so reassociating
them would change which operands get evaluated.

A coalesced identity element is kept, not dropped: @1 + x + (-1)@
rebuilds as @x + 0@. Dropping the literal is only sound when the
remaining operand has the operator's type, which an FFI-lifted chain
does not guarantee (@n .. ""@ coerces a number to a string, and
@-0.0 + 0@ flips the sign bit).

The rule fires only when it coalesces at least two literals, and its
result contains no spine with two coalesceable literals, so it is a
fixed point of itself — the bottom-up driver's re-application
terminates.
-}
reassociateConstants ∷ Applicative m ⇒ RewriteRuleM m Ann
reassociateConstants =
  pure . \case
    e@(PrimBinOp ann op _ _)
      | op == PrimAdd || op == PrimMul →
          setAnn ann <$> coalesceIntChain op (flattenChain op e)
      | op == PrimConcat →
          setAnn ann <$> coalesceConcatChain (flattenChain op e)
    _ → Nothing

{- | The left-to-right operand list of a same-operator tree:
@(1 + x) + (2 + y)@ flattens to @[1, x, 2, y]@.
-}
flattenChain ∷ PrimOp → Exp → [Exp]
flattenChain op = flip go []
 where
  go e acc = case e of
    PrimBinOp _ op' a b | op' == op → go a (go b acc)
    _ → e : acc

{- | Coalesce the int literals of a flattened @+@/@*@ spine into one
constant, placed after the non-literal operands. Guards and rebuild
shape per Note [Reassociating constant chains].
-}
coalesceIntChain ∷ PrimOp → [Exp] → Maybe Exp
coalesceIntChain op operands
  | length ints >= 2
  , not (any isLiteral others)
  , all ((<= maxSafeInteger) . abs) (total : ints) =
      Just case others of
        [] → literalInt total
        (o : os) → foldl' (primBinOp op) o (os <> [literalInt total])
  | otherwise = Nothing
 where
  ints = [i | LiteralInt _ i ← operands]
  others = filter (\case LiteralInt _ _ → False; _ → True) operands
  total = if op == PrimMul then product ints else sum ints

{- | Coalesce every run of adjacent string literals in a flattened
@..@ spine, leaving all other operands in place. Fires only when some
run actually merged. See Note [Reassociating constant chains].
-}
coalesceConcatChain ∷ [Exp] → Maybe Exp
coalesceConcatChain operands = case mergeRuns operands of
  merged@(o : os)
    | length merged < length operands →
        Just (foldl' (primBinOp PrimConcat) o os)
  _ → Nothing
 where
  mergeRuns = \case
    LiteralString _ a : LiteralString _ b : rest →
      mergeRuns (literalString (a <> b) : rest)
    e : rest → e : mergeRuns rest
    [] → []

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

{- | Folds a record update over a statically-known operand — the
'reduceObjectProp' sibling for updates, and the shape used-once local
inlining leaves behind when a record binding's single use is an update
base (issue #240):

  * over a manifest literal, the copy /is/ the patched literal, so one
    allocation replaces an allocation plus a runtime copy;
  * over another update, the two copies coalesce into one with the
    patch lists merged, the later update winning a contested label.

The runtime update ('Language.PureScript.Backend.Lua.Fixture.objectUpdate')
copies its operand's keys and only overwrites existing ones, which
makes both folds exact: a patched-over field's value is dropped, never
evaluated — the licence 'reduceObjectProp' spells out — and a patch
label the literal lacks would patch nothing, so the literal arm
declines rather than reconstruct a record with a key the original
never had (possible only on ill-typed input, see Note [IR is assumed
well-typed]). Both arms strictly shrink (two nodes into one), so the
rule is fixpoint-safe. The result takes the update node's own
annotation, for the reason spelled out on 'reduceObjectProp'.
-}
reduceObjectUpdate ∷ Applicative m ⇒ RewriteRuleM m Ann
reduceObjectUpdate =
  pure . \case
    ObjectUpdate ann (LiteralObject _ props) patches
      | all ((`elem` map fst props) . fst) patches →
          Just . LiteralObject ann $
            [ (label, fromMaybe value (List.lookup label (toList patches)))
            | (label, value) ← props
            ]
    ObjectUpdate ann (ObjectUpdate _ obj earlier) later →
      Just $ ObjectUpdate ann obj (mergePatches earlier later)
    _ → Nothing

{- | Merge two patch lists applied in sequence into one: the later list
wins a contested label in the earlier list's position; its new labels
append in their own order.
-}
mergePatches
  ∷ NonEmpty (PropName, RawExp ann)
  → NonEmpty (PropName, RawExp ann)
  → NonEmpty (PropName, RawExp ann)
mergePatches earlier later =
  ( earlier <&> \(label, value) →
      (label, fromMaybe value (List.lookup label laterList))
  )
    `NE.appendList` [ p
                    | p@(label, _) ← laterList
                    , label `notElem` toList (fst <$> earlier)
                    ]
 where
  laterList = toList later

{- | Folds array reads over an in-place array literal, the
'reduceObjectProp' sibling for arrays (issue #225): the length of a
literal array is its element count, and an in-range index reads the
element directly.

The length folds against the IR element count, which is exact — a
'LiteralArray' codegens to a hole-free positional table, so Lua's @#@
agrees by construction; no reasoning about @#@ over tables with holes
is involved. An out-of-range index reads no existing element (possible
only on ill-typed input, see Note [IR is assumed well-typed]), so the
rule declines, as 'reduceObjectProp' declines a missing label.

The discarded elements are never evaluated — the same call DCE makes
when it drops an unused binding unconditionally. The folded value takes
the read node's own annotation, not the element's, for the reason
spelled out on 'reduceObjectProp'.
-}
reduceArrayRead ∷ Applicative m ⇒ RewriteRuleM m Ann
reduceArrayRead =
  pure . \case
    PrimLen ann (LiteralArray _ elements) →
      Just $ LiteralInt ann (fromIntegral (length elements))
    ArrayIndex ann (LiteralArray _ elements) index →
      setAnn ann <$> elements !!? fromIntegral index
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

{- | Cancel a multi-value binding of a known multi-value result: when a
'LetValues' right-hand side is directly a 'Values' of matching width —
the shape left behind when a CPR worker's body is pasted back into a
binding site — the results are known statically, so the multi-value hop
dissolves into ordinary Let bindings. Elements at 'ParamUnused'
positions are dropped, the licence 'betaReduce' exercises on arguments
facing unused parameters. Binding (never substituting) leaves the
use-count discipline to 'inlineLocalBindings' and DCE, exactly as
'betaReduce' does. A width mismatch is left alone: it is not the shape
any producer constructs, and rewriting it would silently change which
results are dropped or nil-filled.
-}
cancelLetValuesOfValues ∷ Applicative m ⇒ RewriteRuleM m Ann
cancelLetValuesOfValues =
  pure . \case
    LetValues ann params (Values _vAnn es) body
      | length params == length es →
          Just case nonEmpty (mapMaybe bind (zip (toList params) (toList es))) of
            Nothing → body
            Just groupings → Let ann groupings body
     where
      bind ∷ (Parameter Ann, Exp) → Maybe (Grouping (Ann, Name, Exp))
      bind (param, e) =
        paramName param <&> \n → Standalone (noAnn, n, e)
    _ → Nothing

{- | Float a 'Let' out of a 'LetValues' right-hand side:

> letValues ps = (let bs in inner) in body
>   ⟶  let bs in (letValues ps = inner in body)

Evaluation order is unchanged (@bs@, then @inner@, then @body@), GUC
excludes capture, and the rewrite strictly shrinks the RHS — so it
terminates and eventually exposes a 'Values' tail of @inner@ to
'cancelLetValuesOfValues'.
-}
floatLetFromLetValuesRhs ∷ Applicative m ⇒ RewriteRuleM m Ann
floatLetFromLetValuesRhs =
  pure . \case
    LetValues ann params (Let letAnn binds inner) body →
      Just $ Let letAnn binds (LetValues ann params inner body)
    _ → Nothing

{- | Surface a 'LetValues' bound inside a 'Let' grouping — the shape a
rewritten deconstructing call site takes when the call was a let-bound
scrutinee (see "Language.PureScript.Backend.IR.Cpr"):

> let before…; v = (letValues ps = r in inner); after… in body
>   ⟶  let before… in
>         letValues ps = r in (let v = inner; after… in body)

The 'Let' is split at the /first/ such grouping, which is exactly
order-preserving: @before@, then @r@, then @inner@, then @after@, then
@body@ — floating above @before@ instead would reorder @r@ with the
earlier bindings. Once surfaced, @inner@ is typically the constructor
rebox the site rewrite planted, and 'propagateKnownCtorThroughLet'
cancels it against the binder's eliminating reads. Recursive-group
right-hand sides are lambdas, never 'LetValues' nodes, so only
'Standalone' groupings are inspected. Terminates: the total depth of
'LetValues' nodes under Let-grouping right-hand sides strictly
decreases.
-}
floatLetValuesFromLetRhs ∷ Applicative m ⇒ RewriteRuleM m Ann
floatLetValuesFromLetRhs =
  pure . \case
    Let ann groupings body
      | Just (before, (bAnn, v, LetValues lvAnn ps rhs inner), after) ←
          findLetValuesGrouping [] (toList groupings) →
          Just
            let floated =
                  LetValues lvAnn ps rhs $
                    Let ann (Standalone (bAnn, v, inner) :| after) body
             in case nonEmpty before of
                  Nothing → floated
                  Just bs → Let ann bs floated
    _ → Nothing
 where
  findLetValuesGrouping
    ∷ [Grouping (Ann, Name, Exp)]
    → [Grouping (Ann, Name, Exp)]
    → Maybe
        ( [Grouping (Ann, Name, Exp)]
        , (Ann, Name, Exp)
        , [Grouping (Ann, Name, Exp)]
        )
  findLetValuesGrouping _before [] = Nothing
  findLetValuesGrouping before (grouping : after) = case grouping of
    Standalone binding@(_bAnn, _v, LetValues {}) →
      Just (reverse before, binding, after)
    _ → findLetValuesGrouping (grouping : before) after

{- | Sink a constructor-eliminating read (or a record projection) into a
'LetValues' body — the mirror of 'sinkProjectionIntoLet', with the same
licence: the right-hand side evaluates first either way, and the
read's index\/label is static. This carries the read through the
multi-value binding a rewritten call site introduces, down to the
constructor rebox where 'reduceKnownConstructor' folds it.
-}
sinkReadIntoLetValues ∷ Applicative m ⇒ RewriteRuleM m Ann
sinkReadIntoLetValues =
  pure . \case
    ObjectProp ann (LetValues lvAnn ps rhs inner) prop →
      Just $ LetValues lvAnn ps rhs (ObjectProp ann inner prop)
    DataArgumentByIndex ann algTy i (LetValues lvAnn ps rhs inner) →
      Just $ LetValues lvAnn ps rhs (DataArgumentByIndex ann algTy i inner)
    ReflectCtor ann (LetValues lvAnn ps rhs inner) →
      Just $ LetValues lvAnn ps rhs (ReflectCtor ann inner)
    _ → Nothing

{- | Whether the expression contains a multi-value node anywhere — the
mark of a CPR worker ('Values') or wrapper ('LetValues') body. Pasting
either through the call-site inliner is declined: rebuilt as a unary
spine and beta-reduced, a worker's 'Values' tails would land under an
expression-position redex — where a branchy body lowers to a per-call
IIFE (a closure allocation and a trace abort, the exact cost the split
removes) and a leaked 'Values' in a single-value slot is silent
truncation (Note [Multi-value results]) — and a wrapper's 'LetValues'
rebox in expression position lowers to the same per-call IIFE, worse
than the shared wrapper call it replaced. The named worker call is
already cheap and allocation-free; the sites worth unboxing were
rewritten by the split itself.
-}
containsMultiValue ∷ RawExp ann → Bool
containsMultiValue e =
  not
    ( null
        [ ()
        | node ← universeOf subexpressions e
        , case node of
            Values {} → True
            LetValues {} → True
            _ → False
        ]
    )

{- | Case-of-known-constructor for algebraic types (issue #177), the
'reduceObjectProp' twin for data constructors:

  * @ReflectCtor (K a₁ … aₙ)@ — a tag read over a saturated /sum-type/
    constructor application — folds to @K@'s tag string. The surrounding
    equality test then meets 'constantFolding' and
    'removeUnreachableThenBranch' / 'removeUnreachableElseBranch', which
    collapse the decision tree to its live branch.
  * @DataArgumentByIndex i (K a₁ … aₙ)@ — a field read, the shape the
    pattern matcher emits — folds to @aᵢ@.

A constructor value is an in-place 'Ctor' node, saturated by construction
(see Note [Constructor applications are saturated]), so the fold matches it
directly. A partial application is a call of the curried wrapper — a
reference-headed spine, still a function — and is left to
'reduceKnownCtorRefRead', which resolves the reference through the inline
environment ('resolveKnownCtorApp').

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
    ReflectCtor ann (Ctor _ SumType modName tyName ctorName _args) →
      Just $ LiteralString ann (ctorId modName tyName ctorName)
    DataArgumentByIndex ann algTy index (Ctor _ ctorAlgTy _ _ _ args)
      | algTy == ctorAlgTy
      , Just arg ← viaNonEmpty head (List.genericDrop index args) →
          Just (setAnn ann arg)
    _ → Nothing

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
(issue #180). A user-written @Right x@ compiles to a call of the
@Data.Either.Right@ binding — a lambda over a saturated 'Ctor' body
(Note [Constructor applications are saturated]) that 'inlineSaturatedCall'
does paste at saturated sites, beta-reducing to an in-place 'Ctor'. This rule
still cannot lean on that paste: the heuristic paste tiers are disarmed in
the growth veto's fallback sweeps, where the env-reading folds keep firing
(Note [Bounded call-site inlining growth]). Resolving the reference only to
read its arity and tag introduces no 'Ctor' node, so the constructor test the
inlined @bind@ introduces (@justTag == ReflectCtor v@) folds in every sweep,
and a chain that does not fold is not pessimised into pasted constructor
thunks.
-}
propagateKnownCtorThroughLet ∷ InlineEnv → RewriteRuleM SupplyM Ann
propagateKnownCtorThroughLet env = \case
  Let ann groupings body
    | Just (before, (name, algTy, arity, args, tag), after) ←
        findCtorBinding (toList groupings)
    , all ((== 0) . countFreeRefGrouping name) (before <> after)
    , countFreeRef (Local name) body > 0
    , not (Query.hasWholeValueRead name algTy arity body) → do
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
        , (Name, AlgebraicType, Natural, [Exp], Text)
        , [Grouping (Ann, Name, Exp)]
        )
  findCtorBinding = go []
   where
    go
      ∷ [Grouping (Ann, Name, Exp)]
      → [Grouping (Ann, Name, Exp)]
      → Maybe
          ( [Grouping (Ann, Name, Exp)]
          , (Name, AlgebraicType, Natural, [Exp], Text)
          , [Grouping (Ann, Name, Exp)]
          )
    go _before [] = Nothing
    go before (grouping : after) = case grouping of
      Standalone (_bAnn, name, rhs)
        | Just (shape, args) ← resolveKnownCtorApp env rhs
        , let algTy = ctorShapeType shape
              arity = fromIntegral (length args) ∷ Natural
              tag = ctorShapeTag shape
        , -- A self-referencing RHS cannot arise under GUC (a Standalone RHS
          -- does not see its own binder), but 'optimizedExpression' also runs
          -- on non-GUC input; dropping the binding would then dangle the
          -- field-binder that copied the reference (cf. 'inlineLocalBinding').
          countFreeRef (Local name) rhs == 0 →
            Just (reverse before, (name, algTy, arity, args, tag), after)
      _ → go (grouping : before) after

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

-- | Free references to the name across a grouping's right-hand sides.
countFreeRefGrouping ∷ Name → Grouping (Ann, Name, Exp) → Natural
countFreeRefGrouping name grouping =
  sum [countFreeRef (Local name) e | (_ann, _n, e) ← listGrouping grouping]

{- | The literal-array sibling of 'propagateKnownCtorThroughLet' (issue
#225). A fixed-length array pattern reads its scrutinee several times —
one length check plus one read per bound element — so a manifest array
scrutinee is never in place for 'reduceArrayRead' to fold: the match on
@case [10, 20] of [a, b] → …@ lands on

> let v = [10, 20] in
>   if 2 == primLen v then … v[0] … v[1] … else fallthrough

and nothing folds: the rules see @PrimLen (Ref v)@ and
@ArrayIndex (Ref v) i@, never the literal.

This propagates the literal through a 'Standalone' Let binding into the
binder's reads. When the binder is read /only/ through in-range array
reads:

  * each length read becomes the element count (exact for the reason
    spelled out on 'reduceArrayRead');
  * each element read (@ArrayIndex v i@, in range) becomes a fresh
    element-binder @eᵢ@ bound once to the iᵗʰ element — the
    field-binder discipline of 'propagateKnownCtorThroughLet', so an
    element read at several sites is evaluated once, not duplicated;
  * the @v@ binding is dropped, its unread elements discarded with the
    same licence 'reduceArrayRead' spells out.

Trivial and dead element-binders then inline or DCE away, and the
folded reads let the surrounding @Eq@ / @if@ meet 'constantFolding' and
'removeUnreachable*', collapsing the match to its live arm.

The rule declines when the binder is read as a whole value — a sibling
RHS, a non-eliminating position such as an argument to a function, or
an out-of-range index (it reads no element, so there is nothing to bind
for it): dropping the binding would dangle the reference, and keeping
it while binding the elements would duplicate them. GUC keeps the fresh
element-binders unique and the binder resolved by name.
-}
propagateKnownArrayThroughLet ∷ RewriteRuleM SupplyM Ann
propagateKnownArrayThroughLet = \case
  Let ann groupings body
    | Just (before, (name, elements), after) ←
        findArrayBinding (toList groupings)
    , all ((== 0) . countFreeRefGrouping name) (before <> after)
    , countFreeRef (Local name) body > 0
    , let len = fromIntegral (length elements) ∷ Natural
    , not (Query.hasWholeValueArrayRead name len body) → do
        let readIndices = readElementIndices name body
        freshElements ←
          Map.fromList
            <$> traverse
              (\i → (i,) <$> freshName "$elem")
              (toList readIndices)
        let body' = foldArrayReads name len freshElements body
            elementBinds =
              [ Standalone (noAnn, e, element)
              | (i, e) ← Map.toAscList freshElements
              , Just element ← [elements !!? fromIntegral i]
              ]
        pure . Just $ case nonEmpty (before <> elementBinds <> after) of
          Nothing → body'
          Just gs → Let ann gs body'
  _ → pure Nothing
 where
  -- The first Standalone binding whose RHS is an array literal, split
  -- out from its siblings.
  findArrayBinding
    ∷ [Grouping (Ann, Name, Exp)]
    → Maybe
        ( [Grouping (Ann, Name, Exp)]
        , (Name, [Exp])
        , [Grouping (Ann, Name, Exp)]
        )
  findArrayBinding = go []
   where
    go
      ∷ [Grouping (Ann, Name, Exp)]
      → [Grouping (Ann, Name, Exp)]
      → Maybe
          ( [Grouping (Ann, Name, Exp)]
          , (Name, [Exp])
          , [Grouping (Ann, Name, Exp)]
          )
    go _before [] = Nothing
    go before (grouping : after) = case grouping of
      Standalone (_bAnn, name, rhs@(LiteralArray _ elements))
        -- A self-referencing RHS cannot arise under GUC (a Standalone RHS
        -- does not see its own binder), but 'optimizedExpression' also runs
        -- on non-GUC input; dropping the binding would then dangle the
        -- element-binder that copied the reference (cf. 'inlineLocalBinding').
        | countFreeRef (Local name) rhs == 0 →
            Just (reverse before, (name, elements), after)
      _ → go (grouping : before) after

  readElementIndices ∷ Name → Exp → Set Natural
  readElementIndices name = go
   where
    go e = self e <> foldMap go (toListOf subexpressions e)
    self = \case
      ArrayIndex _ (Ref _ (Local n)) i | n == name → Set.singleton i
      _ → mempty

  foldArrayReads ∷ Name → Natural → Map Natural Name → Exp → Exp
  foldArrayReads name len freshElements = go
   where
    go = \case
      PrimLen alAnn (Ref _ (Local n))
        | n == name → LiteralInt alAnn (fromIntegral len)
      ArrayIndex aiAnn (Ref _ (Local n)) i
        | n == name
        , Just e ← Map.lookup i freshElements →
            Ref aiAnn (Local e)
      other → over subexpressions go other

{- | The record twin of 'propagateKnownCtorThroughLet' and
'propagateKnownArrayThroughLet' (issue #240): a 'Standalone' Let
binding whose right-hand side is a manifest record literal and whose
binder is used only field-wise — read at a field, or as the base of a
record update — has its aggregate replaced by scalars, so the table is
never allocated. Each field an occurrence needs is bound once to a
fresh field-binder (the field-binder discipline of
'propagateKnownCtorThroughLet'), in field order, preserving the
evaluation order of the kept field expressions:

  * a field read becomes its field-binder;
  * an update use is reconstructed as a single literal over the known
    field set — patched labels take their patch expressions in place,
    unpatched labels their field-binders — so neither the record nor
    its runtime copy is built ('reduceObjectUpdate' spells out why the
    reconstruction is exact);
  * the record binding is dropped, its unread fields discarded with
    the licence 'reduceObjectProp' spells out.

A field value 'isInlinableValue' admits — binder-free and free to
re-emit — is pasted at its occurrences directly instead of bound, the
substitution 'inlineLocalBinding' would otherwise perform against the
binder one step later, minus the spent binding it leaves for DCE.

Unlike its constructor and array siblings, occurrences are folded
across the trailing sibling groupings as well as the body: Let
bindings scope sequentially (Note [Sequential scoping of Let
bindings]), so the record bound by one grouping is typically the
update base of the next — the defaults pattern
@let opts = {…}; chosen = opts { … } in …@ — and confining the fold
to the body would miss it. The field-binders take the record
binding's position, so they scope over every folded occurrence.

The rule declines when the binder is read as a whole value, read at a
label the literal lacks, or updated at one — either reaches no
existing field, so both count as whole-value reads
('Query.hasWholeValueObjectRead') — and when a preceding sibling
grouping references the name (impossible under GUC scoping, where
earlier bindings do not see later binders, but 'optimizedExpression'
also runs on generated input). Terminates under fixpoint iteration:
each firing drops the bound literal and every reconstruction replaces
an update node one-for-one, so the record-node count strictly
decreases. GUC keeps the fresh field-binders unique and the binder
resolved by name.
-}
propagateKnownObjectThroughLet ∷ RewriteRuleM SupplyM Ann
propagateKnownObjectThroughLet = \case
  Let ann groupings body
    | Just (before, (name, props), after) ←
        findStandaloneBinding
          (\case LiteralObject _ props → Just props; _ → Nothing)
          (toList groupings)
    , all ((== 0) . countFreeRefGrouping name) before
    , let targets = body : (groupingExprs =<< after)
    , sum (countFreeRef (Local name) <$> targets) > 0
    , let labels = Set.fromList (fst <$> props)
    , not (any (Query.hasWholeValueObjectRead (Just labels) name) targets) → do
        let needed = foldMap (neededObjectLabels name labels) targets
        boundFields ←
          bindUnlessInlinable
            "$prop"
            [(l, e) | (l, e) ← props, l `Set.member` needed]
        let replacements =
              Map.fromList
                [(l, replacement) | (l, replacement, _bind) ← boundFields]
            foldReads = foldObjectReads name props replacements
            fieldBinds = [bind | (_l, _rep, Just bind) ← boundFields]
            after' = fmap (fmap (fmap foldReads)) after
        pure . Just $ case nonEmpty (before <> fieldBinds <> after') of
          Nothing → foldReads body
          Just gs → Let ann gs (foldReads body)
  _ → pure Nothing
 where
  -- The labels whose values the folded occurrences reference: every
  -- read label, plus — for each update use — the labels its patches do
  -- not cover (the reconstruction reads those). Unneeded fields bind
  -- nothing and their expressions are dropped.
  neededObjectLabels ∷ Name → Set PropName → Exp → Set PropName
  neededObjectLabels name labels = go
   where
    go e = self e <> foldMap go (toListOf subexpressions e)
    self = \case
      ObjectProp _ (Ref _ (Local n)) l | n == name → Set.singleton l
      ObjectUpdate _ (Ref _ (Local n)) ps
        | n == name →
            Set.difference labels (Set.fromList (toList (fst <$> ps)))
      _ → mempty

  foldObjectReads
    ∷ Name → [(PropName, Exp)] → Map PropName Exp → Exp → Exp
  foldObjectReads name props replacements = go
   where
    go = \case
      ObjectProp pAnn (Ref _ (Local n)) l
        | n == name
        , Just replacement ← Map.lookup l replacements →
            setAnn pAnn replacement
      ObjectUpdate uAnn (Ref _ (Local n)) ps
        | n == name
        , Just merged ← traverse (mergedField ps) props →
            LiteralObject uAnn merged
      other → over subexpressions go other

    -- Total on every occurrence the census admitted: an unpatched
    -- label is in the needed set by construction, so its replacement
    -- lookup succeeds.
    mergedField
      ∷ NonEmpty (PropName, Exp) → (PropName, Exp) → Maybe (PropName, Exp)
    mergedField ps (l, _fieldExp) =
      (l,) <$> case List.lookup l (toList ps) of
        Just patch → Just (go patch)
        Nothing → Map.lookup l replacements

{- | The update-bound companion of 'propagateKnownObjectThroughLet': a
'Standalone' Let binding whose right-hand side is a record update and
whose binder is used only field-wise. The field set behind an update
is unknown, so nothing is reconstructed from scratch; instead the
update's own parts are bound — the base record (only when some
occurrence still needs it) and each patch expression an occurrence
reads — and the copy the binding denoted never runs:

  * a read at a patched label becomes that patch's binder;
  * a read at any other label reads the base record directly — the
    same reach-through 'reduceObjectProp' performs on an in-place
    update;
  * an update use coalesces onto the base with the patch lists
    merged, the later update winning a contested label
    ('reduceObjectUpdate' spells out why the merge is exact): two
    copies become one.

Occurrences are folded across the trailing sibling groupings as well
as the body, the rule declines on a whole-value use or a
preceding-sibling reference, and an 'isInlinableValue' base or patch
expression is pasted directly instead of bound, all for the reasons
spelled out on 'propagateKnownObjectThroughLet'. The binders keep the
original evaluation order — base first, then the kept patches in
patch order; dropped parts are never evaluated, the licence
'reduceObjectProp' spells out. Terminates under fixpoint iteration:
each firing drops the bound update node and coalescing replaces
update nodes one-for-one, so the record-node count strictly
decreases.
-}
propagateObjectUpdateThroughLet ∷ RewriteRuleM SupplyM Ann
propagateObjectUpdateThroughLet = \case
  Let ann groupings body
    | Just (before, (name, (base, patches)), after) ←
        findStandaloneBinding
          (\case ObjectUpdate _ base ps → Just (base, ps); _ → Nothing)
          (toList groupings)
    , all ((== 0) . countFreeRefGrouping name) before
    , let targets = body : (groupingExprs =<< after)
    , sum (countFreeRef (Local name) <$> targets) > 0
    , not (any (Query.hasWholeValueObjectRead Nothing name) targets) → do
        let patchedLabels = Set.fromList (toList (fst <$> patches))
            (needed, Any baseNeeded) =
              foldMap (neededUpdateParts name patchedLabels) targets
        (baseRep, baseBinds) ←
          if not baseNeeded || isInlinableValue base
            then pure (base, [])
            else
              freshName "$rec" <&> \f →
                (Ref noAnn (Local f), [Standalone (noAnn, f, base)])
        boundPatches ←
          bindUnlessInlinable
            "$prop"
            [(l, e) | (l, e) ← toList patches, l `Set.member` needed]
        let replacements =
              Map.fromList
                [(l, replacement) | (l, replacement, _bind) ← boundPatches]
            foldReads = foldUpdateReads name baseRep patches replacements
            binds = baseBinds <> [bind | (_l, _rep, Just bind) ← boundPatches]
            after' = fmap (fmap (fmap foldReads)) after
        pure . Just $ case nonEmpty (before <> binds <> after') of
          Nothing → foldReads body
          Just gs → Let ann gs (foldReads body)
  _ → pure Nothing
 where
  -- Which of the update's parts the folded occurrences reference: the
  -- patch labels that are read directly plus — for each update use —
  -- the ones its own patches do not override, and whether any
  -- occurrence still reaches the base record (an unpatched-label read
  -- or an update use). Unneeded parts bind nothing and their
  -- expressions are dropped.
  neededUpdateParts ∷ Name → Set PropName → Exp → (Set PropName, Any)
  neededUpdateParts name patched = go
   where
    go e = self e <> foldMap go (toListOf subexpressions e)
    self = \case
      ObjectProp _ (Ref _ (Local n)) l
        | n == name →
            if l `Set.member` patched
              then (Set.singleton l, Any False)
              else (mempty, Any True)
      ObjectUpdate _ (Ref _ (Local n)) ps
        | n == name →
            ( Set.difference patched (Set.fromList (toList (fst <$> ps)))
            , Any True
            )
      _ → mempty

  foldUpdateReads
    ∷ Name → Exp → NonEmpty (PropName, Exp) → Map PropName Exp → Exp → Exp
  foldUpdateReads name baseRep patches replacements = go
   where
    go = \case
      ObjectProp pAnn (Ref _ (Local n)) l
        | n == name →
            case Map.lookup l replacements of
              Just replacement → setAnn pAnn replacement
              Nothing → ObjectProp pAnn baseRep l
      ObjectUpdate uAnn (Ref _ (Local n)) ps
        | n == name
        , Just merged ← mergedPatches ps →
            ObjectUpdate uAnn baseRep merged
      other → over subexpressions go other

    -- Total on every occurrence the census admitted: a patch label
    -- the use does not override is in the needed set by construction,
    -- so its replacement lookup succeeds.
    mergedPatches
      ∷ NonEmpty (PropName, Exp) → Maybe (NonEmpty (PropName, Exp))
    mergedPatches ps =
      (`NE.appendList` newer) <$> traverse earlierValue patches
     where
      psList = toList ps
      earlierValue (l, _patchExp) =
        (l,) <$> case List.lookup l psList of
          Just override → Just (go override)
          Nothing → Map.lookup l replacements
      newer =
        [ (l, go p)
        | (l, p) ← psList
        , l `notElem` toList (fst <$> patches)
        ]

{- | The first 'Standalone' binding whose right-hand side the shape
matcher accepts and that does not reference its own binder — which
cannot arise under GUC (a Standalone RHS does not see its own binder),
but 'optimizedExpression' also runs on generated input, and dropping
such a binding would dangle the copied reference (cf.
'findCtorBinding') — split out from its siblings.
-}
findStandaloneBinding
  ∷ (Exp → Maybe rhs)
  → [Grouping (Ann, Name, Exp)]
  → Maybe
      ( [Grouping (Ann, Name, Exp)]
      , (Name, rhs)
      , [Grouping (Ann, Name, Exp)]
      )
findStandaloneBinding match = go []
 where
  go _before [] = Nothing
  go before (grouping : after) = case grouping of
    Standalone (_bAnn, name, rhs)
      | Just matched ← match rhs
      , countFreeRef (Local name) rhs == 0 →
          Just (reverse before, (name, matched), after)
    _ → go (grouping : before) after

-- | The right-hand sides of a grouping's bindings.
groupingExprs ∷ Grouping (ann, Name, RawExp ann) → [RawExp ann]
groupingExprs g = [e | (_ann, _name, e) ← listGrouping g]

{- | Bind each labelled expression to a fresh binder unless
'isInlinableValue' admits it — binder-free and free to re-emit, the
same guard 'inlineLocalBinding' substitutes by — returning per label
the expression its occurrences fold to (the value itself, or a
reference to its binder) and the binding to emit, if any.
-}
bindUnlessInlinable
  ∷ Text
  → [(PropName, Exp)]
  → SupplyM [(PropName, Exp, Maybe (Grouping (Ann, Name, Exp)))]
bindUnlessInlinable prefix = traverse \(l, e) →
  if isInlinableValue e
    then pure (l, e, Nothing)
    else
      freshName prefix <&> \f →
        (l, Ref noAnn (Local f), Just (Standalone (noAnn, f, e)))

{- | The through-a-reference companion of 'reduceKnownConstructor' — the
relationship 'resolveDictionaryProp' bears to 'reduceObjectProp'. A
constructor value used at a saturated site is a reference-headed call: the
uncurrying pass leaves an arity-≥2 constructor as an n-ary worker call
@Cʷ(a₁,…,aₙ)@, and an arity-1 constructor stays @C a@ until
'inlineSaturatedCall' pastes it. A constructor-eliminating read over such a
spine would otherwise stall right before the fold: 'reduceKnownConstructor'
needs an in-place 'Ctor' and 'propagateKnownCtorThroughLet' needs the read
behind a 'Let' binder. 'resolveKnownCtorApp' resolves the reference through
the environment for its declared arity and tag only — no 'Ctor' node is
pasted — and discarded sibling arguments are dropped with the licence
'reduceKnownConstructor' spells out. The folded value takes the read node's
own annotation, not the argument's, for the reason spelled out on
'reduceObjectProp'.
-}
reduceKnownCtorRefRead ∷ Applicative m ⇒ InlineEnv → RewriteRuleM m Ann
reduceKnownCtorRefRead env =
  pure . \case
    -- Field reads fold only at the constructor's own algebraic type, as
    -- in 'reduceKnownConstructor'.
    DataArgumentByIndex ann algTy i spine
      | Just (shape, args) ← resolveKnownCtorApp env spine
      , algTy == ctorShapeType shape
      , Just arg ← args !!? fromIntegral i →
          Just (setAnn ann arg)
    -- Tag reads fold for sum types only, as in 'reduceKnownConstructor'.
    ReflectCtor ann spine
      | Just (shape, _args) ← resolveKnownCtorApp env spine
      , SumType ← ctorShapeType shape →
          Just (LiteralString ann (ctorShapeTag shape))
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

In a 'DirectedPastesOnly' sweep the size-budget path is disarmed and only
an @always@ field resolves — the sweep exists to suppress exactly the
heuristic pastes (Note [Bounded call-site inlining growth]).
-}
resolveDictionaryProp
  ∷ CallSitePastes → InlinePolicy → InlineEnv → RewriteRuleM SupplyM Ann
resolveDictionaryProp pastes policy env = \case
  ObjectProp ann (Ref _ dictName) prop
    | Just (LiteralObject _ props) ← Map.lookup dictName env
    , Just method ← List.lookup prop props
    , countFreeRef dictName method == 0
    , case pastes of
        DirectedPastesOnly →
          fieldPolicy policy dictName prop == Just Always
        _ →
          maybe
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
behaviour-preserving (issue #167). Growth is bounded per paste by
'inlineSizeBudget' and per expression by the growth veto in 'optimizeExp'
(Note [Bounded call-site inlining growth]); a 'CurriedPastesOnly' sweep
disarms the n-ary worker tier below, and a 'DirectedPastesOnly' sweep every
heuristic tier, leaving only the directed-arity gate. The rule declines a
self-referential RHS, which cannot arise for a Standalone binding under GUC
but must not be unfolded on the non-GUC input the rewrite also runs on
(Note [Eta reduction is unsound] is the reason the environment holds no
recursive-group members either).

A binding under an @inline arity=N@ directive takes a different gate: the
site qualifies by argument count alone — at least N arguments applied — and
the explicit directive bypasses the size budget and the manifest-lambda
requirement (pasting a non-lambda value duplicates work, which is exactly
what the user signed for; in a pure language it is behaviour-preserving).
Below N arguments nothing pastes, not even the default guards: the
directive pins the binding as a shared reference at partial sites.

An n-ary call — the direct worker call the uncurry split mints — is not
a unary spine, so 'unwindApp' leaves it whole and the paths above never
see it. It takes the same heuristic gate as the unary tier: a manifest
'AbsN' within 'inlineSizeBudget', minus a multi-value body — the mark
of a result-split worker, whose 'Values' tail pasted into expression
position would truncate in a single-value slot ('containsMultiValue').
The match requires the argument count to equal the manifest parameter
count: workers are saturated by construction, so a mismatched count
marks a shape the pipeline did not produce, left alone rather than
guessed at. The n-ary 'AbsN' root is pasted under the original 'AppN'
node — never rebuilt as a unary spine, which would leave an
under-applied redex ('pasteableRoot') — so the exact-arity 'betaReduce'
consumes it in the same pass.
-}
inlineSaturatedCall
  ∷ CallSitePastes → InlinePolicy → InlineEnv → RewriteRuleM SupplyM Ann
inlineSaturatedCall pastes policy env expr = case expr of
  AppN ann (Ref _ fname) args
    | HeuristicPastes ← pastes
    , _ : _ : _ ← toList args
    , Nothing ← directedArity fname
    , Just rhs@(AbsN _ params _) ← Map.lookup fname env
    , length args == length params
    , expSize rhs <= inlineSizeBudget
    , -- A multi-value body is never pasted (see 'containsMultiValue').
      not (containsMultiValue rhs)
    , countFreeRef fname rhs == 0 →
        (\rhs' → Just (AppN ann rhs' args)) <$> freshenBinders rhs
  (unwindApp → (Ref _ fname, args))
    | not (null args)
    , Just rhs ← Map.lookup fname env
    , -- A multi-value body is never pasted (see 'containsMultiValue').
      not (containsMultiValue rhs) →
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
            | pastes /= DirectedPastesOnly
            , AbsN _ params _ ← rhs
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

{- | Propagate a branch condition's known value into the branches (issue
#223), the Boolean sibling of 'propagateKnownCtorThroughLet': inside
@if c then t else e@ the variable @c@ is 'True' throughout @t@ and
'False' throughout @e@, so its occurrences in the branches are replaced
with the matching literal. The existing folds then finish the job: a
Boolean pattern match compiles to a re-test of the scrutinee behind the
first branch — @if a then "true" else (if false == a then "false" else
error)@ — and with @a@ known 'False' in the else branch the re-test
folds to a literal condition and 'removeUnreachableThenBranch' drops
the synthesized default, collapsing the match to a two-way if.

Only a variable condition propagates: an IR binding is immutable, so
re-reading it in a branch is free and yields the value the test just
observed, and replacing the read with a literal duplicates no work. The
substitution licence is Note [IR is assumed well-typed]: @c@ is a
'Bool', so truth of the test is equality with @true@. The substitution
itself follows the GUC discipline of 'substituteCopyM' — no scope is
threaded, which is exact under unique binders.

Placed after 'removeIfWithEqualBranches': branches that are equal while
still naming @c@ collapse to a single copy, which substituting the two
literals first would unequalize. Fixpoint-safe: the rule fires only
when a branch has a free occurrence of @c@ and leaves none behind, so
it cannot re-fire on its own result, and a 'Ref' becomes a literal
node-for-node, so the tree never grows.
-}
propagateKnownCondIntoBranches ∷ RewriteRuleM SupplyM Ann
propagateKnownCondIntoBranches = \case
  IfThenElse ann cond@(Ref _ name) thenBranch elseBranch
    | countFreeRef name thenBranch + countFreeRef name elseBranch > 0 → do
        thenBranch' ← substituteCopyM name (literalBool True) thenBranch
        elseBranch' ← substituteCopyM name (literalBool False) elseBranch
        pure . Just $ IfThenElse ann cond thenBranch' elseBranch'
  _ → pure Nothing

{- | Eliminate the unreachable default of an exhaustive closed-sum match
(issue #224), the N-constructor generalisation of the Boolean collapse
of issue #223. A @case@ over a sum type lowers to a chain of
constructor-tag tests with a synthesized catch-all
(see 'Language.PureScript.Backend.IR.mkCaseClauses'):

> if     tagA == reflectCtor v then a
> elseif tagB == reflectCtor v then b
> else   error "No patterns matched"

'reduceKnownConstructor' collapses this chain when the scrutinee is a
manifest constructor, but over a runtime value nothing local proves the
default dead: that takes the type's complete constructor set, which is
global information. The 'CtorTagSets' table carries it. When the tags
tested along the chain cover the tested type's whole set, the default
cannot be reached and the final tag test decides nothing, so both go —
the last branch becomes the unconditional else:

> if tagA == reflectCtor v then a else b

Soundness is unconditional (Note [IR is assumed well-typed] supplies
the typing): the table holds the declared constructor set, so covering
it is exact exhaustiveness — no approximation and no assumption about
foreign code. The set equality also carries the guards: a tag of
another type in the chain, or a repeated constructor hiding a gap,
leaves the tested set short of the declared one, and the rule declines.
Only tag reads of one and the same variable chain up — re-reading an
immutable binding observes the value the previous test observed (the
licence of 'propagateKnownCondIntoBranches') — and only a
literal-on-the-left test participates, the one shape the translation
emits. Dropping the final test drops a pure read of that variable, the
same call DCE makes when it drops an unused binding.

The rule meets the in-place read shape above because every optimize
fixpoint runs before common-subexpression elimination could hoist the
repeated @reflectCtor v@ reads into a shared binding (see
'optimizerPipeline'); collapsing to a single read then usually
dissolves the sharing opportunity altogether. Terminates: each firing
removes an 'IfThenElse' and the 'Exception' node, and can only re-fire
on a chain that kept another same-scrutinee default — strictly smaller
each round.
-}
removeUnreachableMatchDefault
  ∷ Applicative m ⇒ CtorTagSets → RewriteRuleM m Ann
removeUnreachableMatchDefault ctorTags =
  pure . \case
    IfThenElse ann cond thenBranch elseBranch
      | Just (scrut, tag) ← tagTest cond
      , Just declared ← Map.lookup tag ctorTags
      , Just (tested, rebuilt) ←
          collapseTail scrut (Set.singleton tag) elseBranch
      , tested == declared →
          Just (IfThenElse ann cond thenBranch rebuilt)
    _ → Nothing
 where
  -- The constructor tag a condition tests against the variable whose
  -- tag it reads: the shape 'mkCaseClauses' emits, literal on the left.
  tagTest ∷ RawExp ann → Maybe (Qualified Name, Text)
  tagTest = \case
    Eq _ (LiteralString _ tag) (ReflectCtor _ (Ref _ v)) → Just (v, tag)
    _ → Nothing

  -- Walk the else-spine of tag tests over the same scrutinee down to
  -- the synthesized default, accumulating the tested tags; the rebuilt
  -- spine has the default gone and the last tag test folded to its
  -- branch.
  collapseTail ∷ Qualified Name → Set Text → Exp → Maybe (Set Text, Exp)
  collapseTail scrut tested = \case
    IfThenElse ann cond thenBranch elseBranch
      | Just (v, tag) ← tagTest cond
      , v == scrut →
          case elseBranch of
            Exception _ _ → Just (Set.insert tag tested, thenBranch)
            _ →
              second (IfThenElse ann cond thenBranch)
                <$> collapseTail scrut (Set.insert tag tested) elseBranch
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

{- | Collapse an if with boolean-literal branches into boolean
operators. Two literal branches make the if the condition or its
negation:

  * @if p then True else False@ ⟶ @p@;
  * @if p then False else True@ ⟶ @not p@ (a 'PrimNot' — a node the IR
    only gained with the primops of issue #178).

One literal branch makes it a short-circuiting operator (issue #203);
the other branch is a 'Bool' too, pinned by the literal (see
Note [IR is assumed well-typed]):

  * @if p then True else b@ ⟶ @p or b@;
  * @if p then False else b@ ⟶ @not p and b@;
  * @if p then a else True@ ⟶ @not p or a@;
  * @if p then a else False@ ⟶ @p and a@.

Every 'Ord' comparison and @/=@ decays to the two-literal shape: their
'case' over the result compiles to a two-way boolean decision tree, so
once the foreign comparison bodies lift to primops (#178) it is the
dominant residual. The half-literal shapes are what a pushed comparison
('pushEqIntoIfBranches') collapses to when the tree has more than one
leaf folding the same way. Lua's @and@\/@or@ short-circuit, so each
fold evaluates exactly what the branches evaluated, in the same order —
and unlike a branch, an operator survives in condition position without
an IIFE.
-}
reduceBooleanIf ∷ Applicative m ⇒ RewriteRuleM m Ann
reduceBooleanIf =
  pure . \case
    IfThenElse _ cond (LiteralBool _ True) (LiteralBool _ False) →
      Just cond
    IfThenElse _ cond (LiteralBool _ False) (LiteralBool _ True) →
      Just (primNot cond)
    IfThenElse _ cond (LiteralBool _ True) elseBranch →
      Just (primBinOp PrimOr cond elseBranch)
    IfThenElse _ cond (LiteralBool _ False) elseBranch →
      Just (primBinOp PrimAnd (primNot cond) elseBranch)
    IfThenElse _ cond thenBranch (LiteralBool _ True) →
      Just (primBinOp PrimOr (primNot cond) thenBranch)
    IfThenElse _ cond thenBranch (LiteralBool _ False) →
      Just (primBinOp PrimAnd cond thenBranch)
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

{- | Case-of-case over a comparison (issue #203), the 'Eq' sibling of
'pushEliminatorIntoIfBranches': a scalar literal compared against an
'IfThenElse' tree distributes into the branches, where each leaf
comparison meets 'constantFolding' and the boolean-if rules collapse
the tree to a flat condition. Without the push the tree sits in
expression position — an IIFE in the generated Lua, allocated and
called per evaluation — the shape an inlined 'Ord' comparison leaves
behind once the tag read distributes over its 'Ordering' decision tree
(issue #180). Guarded by 'eqFoldsThrough': the rule fires only when
every leaf folds, so it never leaves a residual comparison behind, and
the duplicated operand is a scalar literal, free to re-emit. Evaluation
order is preserved: the branch conditions ran before the comparison and
still do. Each push strictly shrinks the tree under the 'Eq', so the
rewrite terminates.
-}
pushEqIntoIfBranches ∷ Applicative m ⇒ RewriteRuleM m Ann
pushEqIntoIfBranches =
  pure . \case
    Eq ann lit (IfThenElse ifAnn cond t e)
      | eqFoldsThrough lit t
      , eqFoldsThrough lit e →
          Just $ IfThenElse ifAnn cond (Eq ann lit t) (Eq ann lit e)
    Eq ann (IfThenElse ifAnn cond t e) lit
      | eqFoldsThrough lit t
      , eqFoldsThrough lit e →
          Just $ IfThenElse ifAnn cond (Eq ann t lit) (Eq ann e lit)
    _ → Nothing

{- | Whether comparing this expression against the literal folds away
completely: it is a scalar literal of the same kind (the comparison
folds to a boolean), or an 'IfThenElse' whose branches both do. Only
then does 'pushEqIntoIfBranches' distribute a comparison into an
'IfThenElse', so the rewrite never trades one expression-position tree
for another.
-}
eqFoldsThrough ∷ RawExp ann → RawExp ann' → Bool
eqFoldsThrough lit = go
 where
  go = \case
    IfThenElse _ann _cond t e → go t && go e
    leaf → isJust (foldEqLiterals lit leaf)

{- | Case-of-case over an 'IfThenElse' whose condition is itself an
'IfThenElse' decision tree (issue #203):

@
IfThenElse (IfThenElse c a b) x y
  ==> IfThenElse c (IfThenElse a x y) (IfThenElse b x y)
@

The tree in condition position — an IIFE in the generated Lua — becomes
statement-position ifs, and evaluation order is preserved exactly: @c@,
then @a@ or @b@, then @x@ or @y@. The unrestricted transformation would
need join points to avoid duplicating @x@ and @y@, so the rewrite is
restricted to the shapes where pushing cannot duplicate work:

  * @a@ and @b@ are boolean literals: the residual ifs are folded right
    away by 'removeUnreachableThenBranch'\/'removeUnreachableElseBranch'
    and each of @x@, @y@ survives in exactly one copy;

  * alternatively @x@ and @y@ are trivial by the 'isInlinableValue'
    test — free to re-emit, and binder-free, so the copies cannot break
    the unique-binders invariant.

Each push strictly shrinks the expression in condition position, so the
rewrite terminates.
-}
pushIfCondIntoBranches ∷ Applicative m ⇒ RewriteRuleM m Ann
pushIfCondIntoBranches =
  pure . \case
    IfThenElse ann (IfThenElse condAnn c a b) x y
      | (isBoolLiteral a && isBoolLiteral b)
          || (isInlinableValue x && isInlinableValue y) →
          Just $
            IfThenElse
              condAnn
              c
              (IfThenElse ann a x y)
              (IfThenElse ann b x y)
    _ → Nothing
 where
  isBoolLiteral ∷ RawExp ann → Bool
  isBoolLiteral = \case
    LiteralBool {} → True
    _ → False

{- | Case-of-case over an eliminator whose scrutinee is an 'IfThenElse'
(issue #243): a cheap elimination — a field, index, length or tag read,
or a call — applied to a conditional distributes into both arms:

@
(if p then a else b).f   ==>  if p then a.f else b.f
(if p then f else g) x   ==>  if p then f x else g x
@

The conditional otherwise sits in expression position — an IIFE in the
generated Lua, allocated and called per evaluation — and the eliminator
never reaches the arms, where the constructor, projection and beta
folds fire ('reduceKnownConstructor', 'reduceObjectProp',
'reduceArrayRead', 'betaReduce'). The canonical producer of the tag-read
shape is an inlined comparison (@compare@\/@>=@): an if-tree of
'Ordering' constructors that @reflectCtor@ over it would otherwise
build at runtime only to read the tag back off (issue #180).

Each arm receives one copy of the eliminator and the arms are never
duplicated, whatever their size, so no gate on them is needed. The only
syntactically duplicated expressions are an application's arguments,
admitted by 'isInlinableValue': pure and bounded to re-emit, and
binder-free, so the copies cannot break the unique-binders invariant.
Only the arm that runs evaluates its argument copy, and evaluation
order is preserved — condition, then arm, then arguments, in both
forms. The unrestricted transformation (arbitrary consumer contexts
around the conditional) needs join points to avoid duplicating the
consumer; this rewrite is deliberately the duplication-free subset.
Each push moves the eliminator onto strictly smaller conditional trees,
so the rewrite terminates.
-}
pushEliminatorIntoIfBranches ∷ Applicative m ⇒ RewriteRuleM m Ann
pushEliminatorIntoIfBranches =
  pure . \case
    ObjectProp ann (IfThenElse ifAnn c t e) prop →
      Just $
        IfThenElse ifAnn c (ObjectProp ann t prop) (ObjectProp ann e prop)
    ArrayIndex ann (IfThenElse ifAnn c t e) index →
      Just $
        IfThenElse ifAnn c (ArrayIndex ann t index) (ArrayIndex ann e index)
    PrimLen ann (IfThenElse ifAnn c t e) →
      Just $ IfThenElse ifAnn c (PrimLen ann t) (PrimLen ann e)
    ReflectCtor ann (IfThenElse ifAnn c t e) →
      Just $ IfThenElse ifAnn c (ReflectCtor ann t) (ReflectCtor ann e)
    DataArgumentByIndex ann algTy index (IfThenElse ifAnn c t e) →
      Just $
        IfThenElse
          ifAnn
          c
          (DataArgumentByIndex ann algTy index t)
          (DataArgumentByIndex ann algTy index e)
    AppN ann (IfThenElse ifAnn c t e) args
      | all isInlinableValue args →
          Just $ IfThenElse ifAnn c (AppN ann t args) (AppN ann e args)
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
      , -- A magic-do effect run must stay a statement: dead-code
        -- elimination keeps the binding even when the paste leaves it
        -- unreferenced (see 'isEffectRun'), so a pasted copy would be a
        -- second execution of the effect, not a relocation.
        not (isEffectRun inlinee)
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
    -- A multi-value body is never pasted (see 'containsMultiValue').
    && not (containsMultiValue rhs)
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
