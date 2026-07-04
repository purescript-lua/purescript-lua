module Language.PureScript.Backend.IR.Optimizer where

import Data.Foldable (foldrM)
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
  , alphaEq
  , bindingExprs
  , countFreeRef
  , countFreeRefs
  , getAnn
  , isNonRecursiveLiteral
  , literalBool
  , rewriteExpBottomUpM
  , substituteCopyM
  , substituteMoveM
  , thenRewrite
  )
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
      , passRun = pure . uniquifyNames
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
  dcePass = gucPass "dce" eliminateDeadCode
  mergeForeignsPass = gucPass "mergeForeigns" mergeForeignsIntoBindings
  floatInPass = gucPass "float-in" floatIn
  magicDoPass =
    Pass
      { passName = "magicDo"
      , passRun = magicDo
      , passRequires = guc
      , passEnsures = guc
      }
  flattenDeepBindsPass =
    Pass
      { passName = "flattenDeepBinds"
      , passRun = flattenDeepBindsM
      , passRequires = guc
      , passEnsures = guc
      }

  gucPass ∷ Text → (UberModule → UberModule) → Pass
  gucPass name run =
    Pass
      { passName = name
      , passRun = pure . run
      , passRequires = guc
      , passEnsures = guc
      }

  wellScoped ∷ Set Invariant
  wellScoped = Set.singleton WellScoped

  guc ∷ Set Invariant
  guc = Set.fromList [WellScoped, UniqueBinders]

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
neverInlineNames UberModule {uberModuleBindings} =
  Set.fromList
    [ qname
    | Standalone (qname, expr) ← uberModuleBindings
    , getAnn expr == Just Never
    ]

optimizeModule ∷ Set QName → UberModule → SupplyM UberModule
optimizeModule neverNames UberModule {..} = do
  (bindings, exports) ←
    foldrM withBinding ([], uberModuleExports) uberModuleBindings
  uberModuleBindings' ←
    traverse (traverse (traverse optimizedExpressionM)) bindings
  uberModuleExports' ← traverse (traverse optimizedExpressionM) exports
  pure
    UberModule
      { uberModuleForeigns
      , uberModuleBindings = uberModuleBindings'
      , uberModuleExports = uberModuleExports'
      }
 where
  withBinding
    ∷ Grouping (QName, Exp)
    → ([Grouping (QName, Exp)], [(Name, Exp)])
    → SupplyM ([Grouping (QName, Exp)], [(Name, Exp)])
  withBinding binding (bindings, exports) =
    case binding of
      Standalone (qname, expr0) → do
        expr ← optimizedExpressionM expr0
        -- See Note [Inline annotations and inlining heuristics]
        let isUsedOnce name =
              1 == Map.findWithDefault 0 (qualifiedQName name) uberModuleFreeRefs
            uberModuleFreeRefs ∷ Map (Qualified Name) Natural =
              foldr
                (\e m → Map.unionWith (+) m (countFreeRefs e))
                mempty
                uberModuleExprs
            uberModuleExprs =
              (bindingExprs =<< uberModuleBindings) <> map snd exports
        if qname `Set.notMember` neverNames
          && (isInlinableExpr expr || isUsedOnce qname)
          then
            (,)
              <$> substituteInBindings qname expr bindings
              <*> substituteInExports qname expr exports
          else pure (Standalone (qname, expr) : bindings, exports)
      RecursiveGroup recGroup → do
        recGroup' ← traverse (traverse optimizedExpressionM) recGroup
        pure (RecursiveGroup recGroup' : bindings, exports)

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
optimizedExpression = runSupply . optimizedExpressionM

optimizedExpressionM ∷ Exp → SupplyM Exp
optimizedExpressionM =
  -- See Note [Eta reduction is unsound]
  fmap fst
    . rewriteExpBottomUpM
      ( constantFolding
          `thenRewrite` betaReduce
          `thenRewrite` betaReduceUnusedParams
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

-- (λx. M) N ===> M[x := N]
-- See Note [IR is assumed well-typed]
betaReduce ∷ RewriteRuleM SupplyM Ann
betaReduce = \case
  App _ (Abs _ (ParamNamed _ param) body) r →
    -- The λ is consumed by the rewrite, so the first inserted occurrence
    -- of the argument may keep its binder names ('substituteMoveM').
    Just <$> substituteMoveM (Local param) r body
  _ → pure Nothing

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

betaReduceUnusedParams ∷ Applicative m ⇒ RewriteRuleM m Ann
betaReduceUnusedParams =
  pure . \case
    App _ (Abs _ (ParamUnused _) body) _arg →
      Just body
    _ → Nothing

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
    (body', Any inlined) ← foldrM inlineLocalBinding (body, Any False) groupings
    pure $ if inlined then Just (Let ann groupings body') else Nothing
  _ → pure Nothing

{- | Inline one binding into the Let's body when the heuristic wants it
/and/ the body actually references it — a zero-occurrence substitution
is a no-op and must not report a change (the honesty contract of
'RewriteRuleM'), or the optimize fixpoint would never converge.

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
inlineLocalBinding ∷ Grouping (Ann, Name, Exp) → (Exp, Any) → SupplyM (Exp, Any)
inlineLocalBinding grouping (body, inlined) =
  case grouping of
    RecursiveGroup _grp → pure (body, inlined) -- Not inlining recursive bindings
    Standalone (_ann, Local → name, inlinee)
      | occurrences > 0
      , countFreeRef name inlinee == 0 -- no self-reference, see above
      , isInlinableExpr inlinee || occurrences == 1 →
          -- The binding survives until DCE drops it, so the inserted copy
          -- must not reuse its binder names ('substituteCopyM').
          (,Any True) <$> substituteCopyM name inlinee body
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
