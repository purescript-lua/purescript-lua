{- | Float a 'Let'-bound value down into the single 'IfThenElse' branch that
uses it (issue #136).

The Lua-AST rule this pass replaces,
@Language.PureScript.Backend.Lua.Optimizer.pushDeclarationsDownTheInnerScope@,
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
once nothing observes it on some path. The hand-verified @eval\/golden.txt@
oracles are the safety net for this policy.

== Progress and termination

A binding only counts as sunk once it has crossed an 'IfThenElse' boundary.
Passing through an intervening 'Let' on the way down (because the binding is
unused in that 'Let's own groupings) is not by itself progress: without this
rule @let y = a in let x = b in x + y@ would swap the two bindings forever,
since floating @y@ past @x@ exposes the very same shape with the roles
reversed. A 'Let' transit therefore only succeeds when the descent past it
does.

'Rewritten Recurse' hands the /children/ of the rewritten node to the
top-down driver, never the node's own root (see
'Language.PureScript.Backend.IR.Types.rewriteExpTopDownM'). When every
grouping of a 'Let' sinks away, the 'Let' node collapses into its own body,
and if that body happens to be another, still-unvisited 'Let', that inner
'Let' would otherwise escape this pass entirely — the same failure class
fixed for DCE by issue #149 (see
'Language.PureScript.Backend.IR.DCE.eliminateDeadCode'). 'refloatLet' guards
against this by re-applying the pass to a collapsed result's own root, for as
long as it is again a 'Let' and further sinking succeeds, before finally
handing control back to the top-down driver.

== GUC

The pass runs under the global-uniqueness condition (GUC = @UniqueBinders@,
issue #139): every local binder is uniquely named at its top-level site, so
relocating a binding underneath other, unrelated binders can never capture
or be captured, and no renaming is needed. See Note [Sequential scoping of
Let bindings] in "Language.PureScript.Backend.IR.Types" for the scoping
convention 'floatInLet' and 'usedInGroupingsRHS' must respect: a grouping
may only be pulled out of a 'Let' when no /later/ sibling's right-hand side
(a 'RecursiveGroup's members included) still needs it in scope there.

== Pipeline placement

Runs once, between the post-merge optimize\/dce fixpoint and @magicDo@, in
'Language.PureScript.Backend.IR.Optimizer.optimizerPipeline': after DCE (a
dead binding is simply gone, never worth sinking), outside any fixpoint (it
never changes a free-reference count, so it cannot re-open an optimize\/dce
opportunity, and iterating it against the inliner would only risk
oscillation), and before @magicDo@\/@flattenDeepBinds@ (which see the final
placement of every 'Let' and must not encounter a half-sunk one). This pass
only rewrites 'Let' nodes and stops descending at 'App'\/'Abs', so it cannot
structurally insert a binding between the links of a bind chain that
@magicDo@ pattern-matches on.
-}
module Language.PureScript.Backend.IR.FloatIn
  ( floatIn
  ) where

import Data.List.NonEmpty qualified as NE
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names (Name, Qualified (Local))
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , RawExp (..)
  , RewriteMod (..)
  , RewriteRuleM
  , Rewritten (..)
  , countFreeRef
  , listGrouping
  , noAnn
  , rewriteExpTopDown
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
  rewrite = rewriteExpTopDown floatInRule

--------------------------------------------------------------------------------
-- The rewrite rule --------------------------------------------------------------

floatInRule ∷ Applicative m ⇒ RewriteRuleM m Ann
floatInRule =
  pure . \case
    Let ann groupings body →
      maybe NoChange (Rewritten Recurse) (refloatLet ann groupings body)
    _ → NoChange

{- | Apply 'floatInLet' once, then keep re-applying it to the result's own
root for as long as that root is again a 'Let' and further sinking
succeeds — closing the Recurse-escape gap described in the module header.
-}
refloatLet ∷ Ann → NonEmpty (Grouping Bind) → Exp → Maybe Exp
refloatLet ann groupings body = settle <$> floatInLet ann groupings body
 where
  settle result = case result of
    Let ann' groupings' body' →
      maybe result settle (floatInLet ann' groupings' body')
    _ → result

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
      | countFreeRef (Local name) cond == 0 →
          case ( countFreeRef (Local name) thenBranch > 0
               , countFreeRef (Local name) elseBranch > 0
               ) of
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

-- | Does any grouping's right-hand side still reference 'name'?
usedInGroupingsRHS ∷ Name → [Grouping Bind] → Bool
usedInGroupingsRHS name = any (any rhsUses . listGrouping)
 where
  rhsUses (_ann, _boundName, rhs) = countFreeRef (Local name) rhs > 0
