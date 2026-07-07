module Language.PureScript.Backend.IR.Optimizer where

import Control.Monad.Writer.CPS (WriterT, runWriterT, tell)
import Data.Foldable (foldrM)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Map qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.DCE (eliminateDeadCode)
import Language.PureScript.Backend.IR.FlattenDeepBinds (flattenDeepBindsM)
import Language.PureScript.Backend.IR.FloatIn (floatIn)
import Language.PureScript.Backend.IR.Inliner (Annotation (..))
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.MagicDo (magicDo)
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName
  , Qualified (Local)
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
import Language.PureScript.Backend.IR.Supply (SupplyM, runSupply)
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , RewriteRuleM
  , WasRewritten (..)
  , alphaEq
  , countFreeRef
  , countFreeRefs
  , getAnn
  , isForeignImport
  , isNonRecursiveLiteral
  , lets
  , literalBool
  , paramName
  , rewriteExpBottomUpM
  , setAnn
  , substituteCopyM
  , substituteMoveM
  , thenRewrite
  , pattern Abs
  , pattern App
  )
import Language.PureScript.Backend.IR.Uncurry (uncurryWorkerWrapper)
import Language.PureScript.Backend.IR.Uniquify (uniquifyNames)

optimizedUberModule ∷ UberModule → UberModule
optimizedUberModule uber =
  runSupply (runSteps (optimizerPipeline (neverInlineNames uber)) uber)

{- | 'optimizedUberModule' with every pass's contract checked by the
linter, failing with the name of the offending pass. Used by the test
suite always, and by the CLI behind the @--lint-ir@ flag.
-}
optimizedUberModuleChecked ∷ UberModule → Either PassCheckFailure UberModule
optimizedUberModuleChecked uber =
  runSupply (runStepsChecked (optimizerPipeline (neverInlineNames uber)) uber)

{- | The IR optimization pipeline. The argument is the set of @inline never@
bindings, collected once from the pristine module before any pass runs:
later rewrites may strip the annotation off a binding's root, so the veto
keys off the name (see Note [Inline annotations and inlining heuristics]).
-}
optimizerPipeline ∷ Set QName → [Step]
optimizerPipeline neverNames =
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
  optimizePass =
    Pass
      { passName = "optimize"
      , passRun = optimizeModule neverNames
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
      , passRun = pure . uncurryWorkerWrapper neverNames
      , passRequires = guc
      , passEnsures = guc
      }
  floatInPass = gucPass "float-in" floatIn
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

{- | The top-level bindings annotated @inline never@, collected once from the
pristine module. Later rewrites can drop the annotation off a binding's root
expression (e.g. constant folding replaces it with a fresh node), so the veto
must key off the name rather than re-reading the annotation after optimization.
See Note [Inline annotations and inlining heuristics].
-}
neverInlineNames ∷ UberModule → Set QName
neverInlineNames UberModule {uberModuleBindings, uberModuleForeigns} =
  Set.fromList $
    [ qname
    | Standalone (qname, expr) ← uberModuleBindings
    , getAnn expr == Just Never
    ]
      -- Foreign accessors merge into the bindings mid-pipeline
      -- ('mergeForeignsIntoBindings'), after this set is collected, so
      -- their annotations are read here.
      <> [ qname
         | (qname, expr) ← uberModuleForeigns
         , getAnn expr == Just Never
         ]

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
optimizeModule ∷ Set QName → UberModule → SupplyM (UberModule, WasRewritten)
optimizeModule neverNames UberModule {..} = runWriterT do
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
  -- Every expression rewrite and every top-level inlining reports into
  -- the pass's 'WasRewritten' result; nothing else in this pass changes
  -- the module, so a converged module reports 'Unmodified'.
  optimizeExp ∷ Exp → WriterT WasRewritten SupplyM Exp
  optimizeExp e = do
    (e', rewritten) ← lift (optimizedExpressionM e)
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
        if qname `Set.notMember` neverNames
          && not (isForeignImport expr)
          && (isInlinableExpr expr || isUsedOnce)
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

{- | Pure wrapper for tests and standalone use: runs the rewrite with
its own supply. Production code uses 'optimizedExpressionM' so all
passes share one supply.
-}
optimizedExpression ∷ Exp → Exp
optimizedExpression = runSupply . fmap fst . optimizedExpressionM

optimizedExpressionM ∷ Exp → SupplyM (Exp, WasRewritten)
optimizedExpressionM =
  -- See Note [Eta reduction is unsound]
  rewriteExpBottomUpM
    ( constantFolding
        `thenRewrite` reduceObjectProp
        `thenRewrite` betaReduce
        `thenRewrite` removeUnreachableThenBranch
        `thenRewrite` removeUnreachableElseBranch
        `thenRewrite` removeIfWithEqualBranches
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

{- Note [Beta reduction and local inlining share an inlining guard]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'betaReduce' and 'inlineLocalBinding' decide whether to paste an expression
into its use sites by the same test: paste only when re-evaluating it cannot
multiply work — the expression is trivial ('isInlinableExpr': a Ref, a
literal, or an @inline-always node) or it is used at most once. Otherwise the
expression stays behind a single 'Let' binding.

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
argument is substituted when trivial or used at most once, and bound by
a 'Let' otherwise; an argument at a 'ParamUnused' position is dropped
with its evaluation — the same call DCE makes when it drops an unused
binding unconditionally. See Note [IR is assumed well-typed].
-}
betaReduce ∷ RewriteRuleM SupplyM Ann
betaReduce = \case
  AppN _ (AbsN _ params body) args
    | length args == length params
    , -- Under GUC the parameters are pairwise-distinct binders. The rule
      -- is also exercised standalone on non-GUC input, where a repeated
      -- parameter name would let the first substitution steal the
      -- occurrences belonging to the last same-named parameter (the one
      -- Lua binds), so it declines rather than mis-substitute.
      distinctParamNames params → do
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
      | isInlinableExpr arg || countFreeRef (Local name) body <= 1 →
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
    (body', inlined) ← foldrM inlineLocalBinding (body, Unmodified) groupings
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
  ∷ Grouping (Ann, Name, Exp)
  → (Exp, WasRewritten)
  → SupplyM (Exp, WasRewritten)
inlineLocalBinding grouping (body, inlined) =
  case grouping of
    RecursiveGroup _grp → pure (body, inlined) -- Not inlining recursive bindings
    Standalone (_ann, Local → name, inlinee)
      | occurrences > 0
      , countFreeRef name inlinee == 0 -- no self-reference, see above
      , -- See Note [Beta reduction and local inlining share an inlining guard]
        isInlinableExpr inlinee || occurrences == 1 →
          -- The binding survives until DCE drops it, so the inserted copy
          -- must not reuse its binder names ('substituteCopyM').
          (,Rewritten) <$> substituteCopyM name inlinee body
      | otherwise → pure (body, inlined)
     where
      occurrences ∷ Natural
      occurrences = countFreeRef name body

-- See Note [Inline annotations and inlining heuristics]
isInlinableExpr ∷ Exp → Bool
isInlinableExpr expr =
  hasInlineAnnotation expr || isRef expr || isNonRecursiveLiteral expr
 where
  isRef ∷ RawExp a → Bool
  isRef = \case
    Ref {} → True
    _ → False

  hasInlineAnnotation ∷ Exp → Bool
  hasInlineAnnotation =
    getAnn >>> \case
      Just Always → True
      Just Never → False
      Nothing → False
