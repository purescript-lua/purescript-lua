{- | Float a 'Let'-bound value down into the single 'IfThenElse' branch that
uses it (issue #136).

The Lua-AST rule this pass replaces (formerly called
@pushDeclarationsDownTheInnerScope@),
sank a declaration into the body of the /returned/ lambda: every call
re-evaluated the moved-in work, losing sharing, and a value whose evaluation
used to be unconditional started throwing only when the function was
actually called. This pass performs the same relocation at the IR level
instead, where free-reference counts are available and lambdas are visible
as 'Abs' nodes rather than opaque closures, so it can rule out exactly the
shape that broke sharing: __a binding is never sunk across an 'Abs'__.
Sinking only ever crosses into one arm of an 'IfThenElse' — the sole
conditional node in the IR — so the value is either evaluated in the branch
that uses it (as before) or not at all (the branch not taken), never
re-evaluated per call.

== Semantics: reordered, not duplicated, evaluation

Sinking a 'Standalone' binding into its single using branch can move its
evaluation from before the 'IfThenElse' to after the condition, and drops it
entirely on the branch not taken — including when its right-hand side is an
'Exception'. This is consistent with the rest of the pipeline:
'Language.PureScript.Backend.IR.DCE.eliminateDeadCode' already drops an
unreferenced binding unconditionally, 'Exception' right-hand sides included,
so the compiler already treats a let-bound value as discardable\/reorderable
once nothing observes it on some path. The @Golden.FloatIn@ eval oracle
observes this policy at runtime: its @tick@ foreign function prints a line
every time it is evaluated, so a binding evaluated on the branch not taken
(a missed sink) or re-evaluated per call of a lambda (the #136 bug shape)
both change the hand-verified output.

== Bottom-up rewriting, progress, and termination

A binding only counts as sunk once it has crossed an 'IfThenElse' boundary.
Passing through an intervening 'Let' on the way down (because the binding is
unused in that 'Let's own groupings) is not by itself progress: counted as
such, @let y = a in let x = b in x + y@ would swap its two bindings on every
run of the pass, breaking idempotence. A 'Let' transit therefore only
succeeds when the descent past it does.

The traversal is bottom-up ('transformOf'): a 'Let' decides its groupings'
fate only after all its subexpressions have been rewritten. This makes one
pass complete, and hence idempotent. A top-down driver gets this wrong twice
over: it decides an outer 'Let' before the inner sink that would confine a
name's uses to a single branch has happened (leaving work behind for a
second run to find), and when every grouping of a 'Let' sinks away and the
node collapses into its own body, a collapsed root that is again a 'Let'
escapes the rewrite entirely — the failure class fixed for DCE by issue #149
(see 'Language.PureScript.Backend.IR.DCE.eliminateDeadCode'). Bottom-up, the
collapsed body has already been fully rewritten, so neither problem arises.
Termination is structural: every node is rewritten exactly once, and
'sinkBinding' only walks down pre-existing structure.

== GUC

The pass runs under the global-uniqueness condition (GUC = @UniqueBinders@,
issue #139): every local binder is uniquely named at its top-level site, so
relocating a binding underneath other, unrelated binders can never capture
or be captured, and no renaming is needed ('usesName' also relies on this
for its occurrence scan). See Note [Sequential scoping of Let bindings] in
"Language.PureScript.Backend.IR.Types" for the scoping convention
'floatInLet' and 'usedInGroupingsRHS' must respect: a grouping may only be
pulled out of a 'Let' when no /later/ sibling's right-hand side (a
'RecursiveGroup's members included) still needs it in scope there.

== Pipeline placement

Runs once, between the post-merge optimize\/dce fixpoint and @magicDo@, in
'Language.PureScript.Backend.IR.Optimizer.optimizerPipeline': after DCE (a
dead binding is simply gone, never worth sinking), outside any fixpoint
(see the pipeline comment there for the trade-off taken), and before
@magicDo@\/@flattenDeepBinds@ (which see the final placement of every 'Let'
and must not encounter a half-sunk one). The rewrite only mutates 'Let'
nodes, and 'sinkBinding' never descends into an 'App' or an 'Abs', so a
relocated binding re-anchors either at the root of an 'IfThenElse' branch or
directly above the 'Let'\/'Abs' that blocked its descent — it is never
spliced into the middle of an application spine that @magicDo@
pattern-matches on.

== Nesting

Sinking relocates a binding's right-hand side into the Lua block generated
for each crossed 'IfThenElse' branch — one parser level per boundary. A deep
sink of a syntactically deep right-hand side can therefore push a chunk that
measured just under the Lua 5.1 parser-nesting cap over it.
'Language.PureScript.Backend.Lua.NestingCheck' remains the post-codegen
backstop: such a chunk is rejected with a clear compiler error instead of
being emitted as unloadable Lua.
-}
module Language.PureScript.Backend.IR.FloatIn
  ( floatIn
  ) where

import Control.Lens (anyOf, cosmosOf, transformOf)
import Data.List.NonEmpty qualified as NE
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names (Name, Qualified (Local))
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , RawExp (..)
  , listGrouping
  , noAnn
  , subexpressions
  )

-- | The moved unit: a grouping's annotation, bound name, and right-hand side.
type Bind = (Ann, Name, Exp)

floatIn ∷ UberModule → UberModule
floatIn uber@UberModule {uberModuleBindings, uberModuleExports} =
  uber
    { uberModuleBindings = map (fmap (fmap rewrite)) uberModuleBindings
    , uberModuleExports = map (fmap rewrite) uberModuleExports
    }
 where
  -- Bottom-up: a Let decides its groupings' fate only after all its
  -- subexpressions have been rewritten (see the module header).
  rewrite ∷ Exp → Exp
  rewrite = transformOf subexpressions \case
    expr@(Let ann groupings body) →
      fromMaybe expr (floatInLet ann groupings body)
    expr → expr

--------------------------------------------------------------------------------
-- The rewrite -----------------------------------------------------------------

{- | One pass over a 'Let's own groupings, right to left: try to sink each
'Standalone' binding into 'body' (which, as groupings to its right are
decided, already reflects their fate). 'Nothing' means nothing in this
'Let' could move.
-}
floatInLet ∷ Ann → NonEmpty (Grouping Bind) → Exp → Maybe Exp
floatInLet ann groupings body =
  case foldr step ([], body, False) (toList groupings) of
    (_, _, False) → Nothing
    (kept, restBody, True) →
      Just case NE.nonEmpty kept of
        Nothing → restBody
        Just keptNE → Let ann keptNE restBody
 where
  step
    ∷ Grouping Bind
    → ([Grouping Bind], Exp, Bool)
    → ([Grouping Bind], Exp, Bool)
  step grouping (kept, restBody, moved) = case grouping of
    Standalone bind@(_bindAnn, name, _rhs)
      | not (usedInGroupingsRHS name kept)
      , Just restBody' ← sinkBinding bind restBody →
          (kept, restBody', True)
    _ → (grouping : kept, restBody, moved)

{- | Try to push 'bind' down into 'expr': zero or more transparent 'Let'
transits followed by exactly one 'IfThenElse' boundary crossing — never a
lambda. 'Nothing' means no progress: 'bind' must stay exactly where it was.
-}
sinkBinding ∷ Bind → Exp → Maybe Exp
sinkBinding bind@(_bindAnn, name, _rhs) = go
 where
  go expr = case expr of
    IfThenElse ifAnn cond thenBranch elseBranch
      | not (usesName name cond) →
          case (usesName name thenBranch, usesName name elseBranch) of
            (True, False) →
              Just (IfThenElse ifAnn cond (sinkOrWrap thenBranch) elseBranch)
            (False, True) →
              Just (IfThenElse ifAnn cond thenBranch (sinkOrWrap elseBranch))
            _ → Nothing
    Let letAnn gs innerBody
      | not (usedInGroupingsRHS name (toList gs)) →
          Let letAnn gs <$> go innerBody
    _ → Nothing

  -- Sink deeper if possible; otherwise this branch boundary is the stop:
  -- wrap the binding right here, which is itself progress (see the module
  -- header — crossing the boundary counts even without a deeper transit).
  sinkOrWrap branch = fromMaybe (wrapBind branch) (go branch)

  wrapBind = Let noAnn (Standalone bind :| [])

--------------------------------------------------------------------------------
-- Helper functions ------------------------------------------------------------

-- | Does any grouping's right-hand side still reference 'name'?
usedInGroupingsRHS ∷ Name → [Grouping Bind] → Bool
usedInGroupingsRHS name = any (any rhsUses . listGrouping)
 where
  rhsUses (_ann, _boundName, rhs) = usesName name rhs

{- | Does the expression reference the locally-bound @name@? Under the GUC
no two binders in the module share a name, so no subterm can rebind @name@
and a bare occurrence scan is an exact free-reference test — an
early-exiting one, unlike
'Language.PureScript.Backend.IR.Types.countFreeRef', which builds the full
reference-count map on every query.
-}
usesName ∷ Name → Exp → Bool
usesName name = anyOf (cosmosOf subexpressions) \case
  Ref _ann (Local refName) → refName == name
  _ → False
