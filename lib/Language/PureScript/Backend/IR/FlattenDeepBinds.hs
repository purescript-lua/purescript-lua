{- | Flatten deeply-nested expression trees that would otherwise overflow Lua
5.1's parser-nesting cap.

Lua's recursive-descent parser refuses any chunk nested past ~200 levels
(@chunk has too many syntax levels@, @LUAI_MAXCCALLS@) — a correctness failure
unique to the Lua backend (issue #104): valid PureScript the compiler accepts
but emits unloadable Lua for. 'Language.PureScript.Backend.IR.MagicDo' fixes one
shape (the 'Effect'\/'ST' @do@-block, lowered to a flat statement sequence); this
pass fixes the rest, monad-agnostically, by recognising deep nesting from its
/structure/ rather than from any instance name.

Two cooperating strategies are dispatched by /where the depth lives/:

== Strategy A — continuation lambda-lifting

A straight-line @do@ block of /any/ monad desugars to a right-nested tree of
continuation closures, depth running through trailing lambdas:

>   bind m1 (\x1 -> bind m2 (\x2 -> … bind mn (\xn -> final)))

Any chain @f a1 (\x1 -> f a2 (\x2 -> …))@ of this shape — @>>=@, a non-@bind@
CPS combinator, @bracket@\/@with@-style nesting — is split into segments of at
most 'segmentSize' steps, each cut's tail lambda-lifted (Johnsson) into a named
@$kontN@ helper whose free continuation variables are passed as explicit
parameters. The original

>   bind m1 (\x1 -> … bind mC (\xC -> <tail>) …)

becomes (last-defined-first, so each helper only references already-defined
ones — see Note [Sequential scoping of Let bindings]):

>   let $kontM = \live… \xK -> <segment M>
>       …
>       $kont2 = \live… \xC -> bind m_{C+1} (\… -> … $kont3 live… …)
>   in  bind m1 (\x1 -> … bind mC (\xC -> $kont2 live… xC) …)

Each helper body and the @let@ body nest at most 'segmentSize' binds deep, so
the whole expression stays flat regardless of the original chain length. This
relocates closures and forwards their environment but never reorders, drops, or
duplicates a call, so it is semantics-preserving for /any/ monad — strict Lua
included: the introduced @$kontN@ calls pass only variables (no evaluation
reordering) and @let@-binding a helper does not run its body.

== Strategy B — application-spine sequentialisation

Applicative and flipped-bind chains carry their depth in a /value-argument/
position instead of a trailing lambda — there is no binder to cross:

>   apply (apply (apply (map f a) b) c) …      -- ado / <*>
>   bindFlipped k1 (bindFlipped k2 (bindFlipped k3 …))   -- =<<

At the IR level (which has no @BinOp@) these — and deep left-associated @<>@ or
ordinary nested call spines — are all contiguous 'App' trees. The deepest
application path is rebuilt bottom-up, /sealing the accumulator into a fresh
@$tmpN@ local every 'segmentSize' frames/ (segmented A-normalisation, not a
@$tmp@ per 'App'):

>   let $tmp0 = apply (apply … (map f a) …) m40   -- ≤ segmentSize frames
>       $tmp1 = apply (apply … $tmp0 …)      m80
>       …
>   in  apply (apply … $tmpN …) mlast

Each segment then nests at most ~'segmentSize' deep and the count of locals is
about @depth \/ segmentSize@. Both bounds matter: a 'Let' of 'Standalone'
bindings lowers to a flat sequence of Lua @local@ statements (parsed
iteratively, not recursively, so parse nesting is removed), but Lua 5.1 /also/
caps a function at 200 locals — a naive @$tmp@-per-'App' overflows that cap on a
long spine, hence the segmentation.

Soundness. The rewrite preserves /data flow/ exactly: it never changes which
call receives which argument (only the sequential @let@s relocate intermediate
results), so the computed value is unchanged — the property tests and runnable
goldens confirm this. What it can change is the temporal order in which the
spine's independent operands are /evaluated/: for a spine whose depth lives in
the argument position (@bindFlipped@\/@=<<@), a deep argument segment is
evaluated before the outer callee operand. This is sound for the spines Strategy
B targets, because Lua evaluates the entire strict spine regardless of use — so
divergence is order-independent (any diverging operand diverges the whole
expression either way) — and the off-spine operands of a non-Effect\/ST monadic
spine are pure, total values whose evaluation has no observable effect. The only
behaviour reordering could affect is /which/ exception surfaces first when two
operands both crash, which the targeted pure spines do not exhibit. The descent
stops at every non-'App' node: 'Abs' bodies and branch positions are deferred
and never hoisted across (a deep off-spine operand is instead re-flattened in
place by the top-down rewrite's later descent), so laziness and short-circuiting
are untouched.

== Dispatch and termination

At each node the top-down rewrite tries Strategy A first (a recognised chain
longer than 'threshold'); a bind chain hides its depth under lambdas, so its
application-spine depth is tiny and Strategy B never fires on it. Strategy B
then fires on any remaining contiguous 'App' spine deeper than 'threshold'.
Both emit segments shallower than 'threshold', and B's output binds every 'App'
to a depth-1 right-hand side, so the 'Recurse' rewrite cannot re-fire on its own
output.

== GUC safety: no shifting, fresh helper parameters

The pass runs under GUC (every local uniquely named, established by
'Language.PureScript.Backend.IR.Uniquify.uniquifyNames' at the front of the
pipeline and preserved throughout), so a reference resolves to its binder by
name alone — no De Bruijn shifting is ever needed here. A Strategy-A helper's
parameters are new binders for the chain's already-bound live variables, so
they cannot reuse the outer binders' names under 'UniqueBinders': each is
minted fresh and the helper body's free references are repointed to it (see
'freshenParams'); the call site still passes the live variables by their
original name, which remains in scope there. Strategy B's @$tmpN@ binders are
freshly minted from the start, and the @$@ prefix cannot collide with a
PureScript identifier or a uniquify digit-suffix mint.

== Why it must run after 'magicDo'

Strategy A does /not/ check whether the monad is 'Effect'\/'ST': 'magicDo' runs
first (the previous step of 'optimizedUberModule') and rewrites every
'Effect'\/'ST' bind chain into a 'Let' thunk, so the only bind chains that reach
this pass are non-'Effect'\/'ST'. Were the order reversed this pass would
lambda-lift those chains too — still correct, but redundant and worse code than
the magic-do statement sequence.

== Bail-out

Lambda-lifting bounds /nesting/ but the innermost closure of a segment captures
the segment's own binders plus the forwarded live set as upvalues, and Lua 5.1
caps a function at 60 upvalues (@LUAI_MAXUPVALUES@, see @docs\/QUIRKS.md@). When
the live set at a cut is too large Strategy A bails (returns 'NoChange', leaving
the chain nested): the program then overflows exactly as it does today, now
caught by the post-codegen nesting detector
('Language.PureScript.Backend.Lua.NestingCheck'). Strategy B introduces only
plain locals (no upvalues) and never bails. Packing the environment into a
single table to cut the upvalue cost to one is a future upgrade.
-}
module Language.PureScript.Backend.IR.FlattenDeepBinds
  ( flattenDeepBinds
  , flattenDeepBindsM
  ) where

import Data.List qualified as List
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , Qualified (Local)
  )
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName, runSupply)
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Index (..)
  , Parameter (..)
  , RawExp (..)
  , RewriteMod (..)
  , RewriteRuleM
  , Rewritten (..)
  , countFreeRefs
  , noAnn
  , rewriteExpTopDownM
  , substituteCopyM
  )

-- | 'flattenDeepBindsM' with a private supply, for standalone use.
flattenDeepBinds ∷ UberModule → UberModule
flattenDeepBinds = runSupply . flattenDeepBindsM

{- | Flatten deeply-nested expression trees in every binding and export of the
module. The supply counter is threaded across the whole module so the minted
@$kontN@\/@$tmpN@ names are globally unique.
-}
flattenDeepBindsM ∷ UberModule → SupplyM UberModule
flattenDeepBindsM uber@UberModule {uberModuleBindings, uberModuleExports} = do
  bindings' ← traverse (traverse (traverse rewrite)) uberModuleBindings
  exports' ← traverse (traverse rewrite) uberModuleExports
  pure uber {uberModuleBindings = bindings', uberModuleExports = exports'}
 where
  rewrite ∷ Exp → SupplyM Exp
  rewrite = rewriteExpTopDownM flattenRule

--------------------------------------------------------------------------------
-- Rewrite rule ----------------------------------------------------------------

{- | Dispatch the two strategies. Strategy A handles a recognised continuation
chain longer than 'threshold' (depth under trailing lambdas); a bind chain's
application-spine depth is tiny, so Strategy B only ever sees the remaining deep
'App' spines. Either may leave the expression unchanged ('NoChange'), in which
case 'Language.PureScript.Backend.Lua.NestingCheck' remains the backstop.
-}
flattenRule ∷ RewriteRuleM SupplyM Ann
flattenRule expr
  | (steps, finalAction) ← peelChain expr
  , length steps > threshold =
      maybe NoChange (Rewritten Recurse) <$> lambdaLift steps finalAction
  | spineDepth expr > threshold =
      maybe NoChange (Rewritten Recurse) <$> sequentialiseSpine expr
  | otherwise = pure NoChange

--------------------------------------------------------------------------------
-- Strategy A: continuation lambda-lifting -------------------------------------

{- | One step of a continuation chain: @f action (\param -> …)@. Fields: the
head, the continuation parameter, and the action — all kept verbatim (only the
continuation /structure/ is rewritten).
-}
data Step = Step Exp (Parameter Ann) Exp

{- | Peel a maximal prefix of @f action (\param -> rest)@ steps, returning them
together with the first expression that is not such a step (the chain's final
action). An empty step list means @expr@ is not a chain head and is left
untouched. Recognition is purely structural: any head whose two-argument
application ends in a lambda is a step, regardless of the monad or combinator.
-}
peelChain ∷ Exp → ([Step], Exp)
peelChain = go
 where
  go expr = case asStep expr of
    Just (step, rest) → first (step :) (go rest)
    Nothing → ([], expr)

-- | Recognise @f action (\param -> rest)@ as a step plus its continuation body.
asStep ∷ Exp → Maybe (Step, Exp)
asStep expr = case spine expr of
  (hd, [action, k])
    | Abs _ann param rest ← k →
        Just (Step hd param action, rest)
  _ → Nothing

{- | Lambda-lift a recognised chain into a flat @let@ of @$kontN@ helpers.
Returns 'Nothing' (bail, leave the chain nested) when the forwarded live set at
some cut exceeds the upvalue budget.
-}
lambdaLift ∷ [Step] → Exp → SupplyM (Maybe Exp)
lambdaLift steps finalAction =
  -- Build bottom-up: the deepest segment carries the final action; each
  -- shallower segment ends by calling the helper wrapping the one below it.
  -- @reverse segments@ is deepest-first, so its head is the deepest segment and
  -- its tail are the upper segments in the order the fold needs (a segment is
  -- processed only after the helper it calls has been built).
  case reverse (chunksOf segmentSize steps) of
    [] → pure Nothing
    deepestSeg : upperDeepFirst → do
      let deepest = buildSteps deepestSeg finalAction
      (body1, konts) ← foldlM cut (deepest, []) upperDeepFirst
      let maxLive = foldl' max 0 (map fst konts)
      pure
        if null konts || maxLive > maxLiveSet
          then Nothing
          -- @konts@ accumulates deepest-first via prepend, so it ends up
          -- shallowest-first; reverse so the deepest helper is defined first
          -- (a helper only references already-defined ones).
          else Just (letHelpers (reverse (map snd konts)) body1)
 where
  -- Position of each named binder in the chain, for a stable parameter order.
  bindOrder ∷ Map Name Int
  bindOrder =
    Map.fromList
      [ (name, i)
      | (i, Step _ (ParamNamed _ name) _) ← zip [0 ..] steps
      ]
  chainBound ∷ Set Name
  chainBound = Map.keysSet bindOrder

  -- The earlier-bound chain variables a helper body still references, in
  -- binding order: exactly the parameters the helper must take and the call
  -- site must forward. Computed from the built body, so a @$kontN@ call's
  -- variable arguments propagate the live set transitively across helpers.
  liveVars ∷ Exp → [Name]
  liveVars body =
    List.sortOn
      (\n → Map.findWithDefault maxBound n bindOrder)
      [ n
      | Local n ← Map.keys (countFreeRefs body)
      , Set.member n chainBound
      ]

  -- Turn the current deepest body into a named helper and prepend a segment
  -- whose tail calls it.
  cut
    ∷ (Exp, [(Int, Grouping (Ann, Name, Exp))])
    → [Step]
    → SupplyM (Exp, [(Int, Grouping (Ann, Name, Exp))])
  cut (deepBody, konts) seg = do
    kname ← freshKontName
    let params = liveVars deepBody
    (freshParams, deepBody') ← freshenParams params deepBody
    let helperDef = curryAbs freshParams deepBody'
        helper = Standalone (noAnn, kname, helperDef)
        callTail = applyToVars (refLocal0 kname) params
        body = buildSteps seg callTail
    pure (body, (length params, helper) : konts)

  -- The helper's parameters are new binders for the (already-bound) live
  -- chain variables, so under GUC ('UniqueBinders') they cannot reuse the
  -- outer binders' names: mint a fresh name per parameter and repoint the
  -- body's free references to it. The outer binders survive unchanged —
  -- the call site (built by 'cut' from the un-substituted 'params') still
  -- passes them by their original name.
  freshenParams ∷ [Name] → Exp → SupplyM ([Name], Exp)
  freshenParams params body = foldlM step ([], body) params
   where
    step (freshNames, b) name = do
      name' ← freshName (nameToText name <> "$")
      b' ← substituteCopyM (Local name) (refLocal0 name') b
      pure (freshNames <> [name'], b')

-- | Rebuild a segment's nested @f action (\param -> …)@ wrapping a tail.
buildSteps ∷ [Step] → Exp → Exp
buildSteps steps tailExp =
  foldr step tailExp steps
 where
  step ∷ Step → Exp → Exp
  step (Step hd param action) rest =
    App noAnn (App noAnn hd action) (Abs noAnn param rest)

-- | @\\p1 -> \\p2 -> … -> body@ (p1 outermost).
curryAbs ∷ [Name] → Exp → Exp
curryAbs params body =
  foldr (Abs noAnn . ParamNamed noAnn) body params

-- | @f p1 p2 …@, applying the variables in the same order as 'curryAbs'.
applyToVars ∷ Exp → [Name] → Exp
applyToVars = foldl' \f p → App noAnn f (refLocal0 p)

--------------------------------------------------------------------------------
-- Strategy B: application-spine sequentialisation -----------------------------

{- | Length of the longest contiguous chain of strict 'App' nodes reachable from
this expression — the parse nesting Strategy B can flatten. Counts both the
callee and the argument side of each 'App' (Lua nests both @f(…)@ and its
argument) and stops at every non-'App' node: 'Abs' bodies and branch positions
are deferred (and handled by Strategy A or a later descent), and other
constructs carry their own depth that 'sequentialiseSpine' leaves in place.
-}
spineDepth ∷ RawExp ann → Int
spineDepth = \case
  App _ann f a → 1 + max (spineDepth f) (spineDepth a)
  _ → 0

{- | One 'App' node on a spine's deepest path, holding the off-path operand
verbatim. 'rebuildFrame' reattaches it to the deep child.
-}
data Frame
  = -- | @App deep sibling@ — the deep child is the callee.
    OnCallee Ann Exp
  | -- | @App sibling deep@ — the deep child is the argument.
    OnArg Ann Exp

rebuildFrame ∷ Frame → Exp → Exp
rebuildFrame (OnCallee ann sibling) deep = App ann deep sibling
rebuildFrame (OnArg ann sibling) deep = App ann sibling deep

{- | Peel the deepest contiguous application path, outermost frame first, down
to the innermost non-'App' base. Following the deeper child at each node makes
@length (fst (decompose e)) == 'spineDepth' e@.
-}
decompose ∷ Exp → ([Frame], Exp)
decompose = \case
  App ann f a
    | spineDepth f >= spineDepth a → first (OnCallee ann a :) (decompose f)
    | otherwise → first (OnArg ann f :) (decompose a)
  base → ([], base)

{- | Sequentialise a deep strict-application spine: rebuild its deepest path
bottom-up (innermost first), sealing the accumulator into a fresh @$tmpN@ local
every 'segmentSize' frames. Each segment then nests at most ~'segmentSize' deep
and the number of locals is about @depth \/ segmentSize@ — staying under both of
Lua 5.1's per-function limits (~200 parser-nesting levels and 200 locals). Data
flow is preserved exactly; operand evaluation order may shift but only for pure,
total operands (see the module header's soundness note). The off-path operands
are kept verbatim; deep ones are flattened in turn by the top-down rewrite's
descent. Returns 'Nothing' when the path is too short to need sealing.
-}
sequentialiseSpine ∷ Exp → SupplyM (Maybe Exp)
sequentialiseSpine expr =
  case decompose expr of
    (frames, base)
      | length frames <= segmentSize → pure Nothing
      | otherwise → do
          (binds, body) ← foldlM seal ([], base) (zip [1 ..] (reverse frames))
          pure (Just (letHelpers (reverse binds) body))
 where
  -- Fold frames innermost-first, cutting a segment whenever 'segmentSize' of
  -- them have accumulated (@i@ counts frames consumed so far).
  seal
    ∷ ([Grouping (Ann, Name, Exp)], Exp)
    → (Int, Frame)
    → SupplyM ([Grouping (Ann, Name, Exp)], Exp)
  seal (binds, acc) (i, frame) = do
    let acc' = rebuildFrame frame acc
    if i `mod` segmentSize == 0
      then do
        name ← freshTmpName
        pure (Standalone (noAnn, name, acc') : binds, refLocal0 name)
      else pure (binds, acc')

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

letHelpers ∷ [Grouping (Ann, Name, Exp)] → Exp → Exp
letHelpers [] body = body
letHelpers (h : hs) body = Let noAnn (h :| hs) body

-- | Unwind an application into its head and arguments (left to right).
spine ∷ Exp → (Exp, [Exp])
spine = go []
 where
  go ∷ [Exp] → Exp → (Exp, [Exp])
  go acc (App _ann f a) = go (a : acc) f
  go acc h = (h, acc)

refLocal0 ∷ Name → Exp
refLocal0 name = Ref noAnn (Local name) (Index 0)

freshKontName ∷ SupplyM Name
freshKontName = freshName "$kont"

freshTmpName ∷ SupplyM Name
freshTmpName = freshName "$tmp"

chunksOf ∷ Int → [a] → [[a]]
chunksOf _ [] = []
chunksOf n xs = let (h, t) = splitAt n xs in h : chunksOf n t

--------------------------------------------------------------------------------
-- Tunables --------------------------------------------------------------------

{- | Only fire on chains\/spines deeper than this. Shorter ones are below Lua's
nesting cap and are left untouched, so existing goldens do not churn. Must exceed
'segmentSize' so the helper\/body segments Strategy A produces never re-fire
(which guarantees termination of the 'Recurse' rewrite); Strategy B's output
binds every 'App' to a depth-1 right-hand side and so cannot re-fire either.
-}
threshold ∷ Int
threshold = 50

{- | Steps per Strategy-A segment. Each step is a few Lua nesting levels, so this
caps a helper body's nesting well under @LUAI_MAXCCALLS@ (~200). Kept below
'threshold' (see above). Calibrated against the generated golden's measured
nesting.
-}
segmentSize ∷ Int
segmentSize = 40

{- | Bail when a Strategy-A helper's forwarded live set exceeds this. The
innermost closure of a segment captures roughly @segmentSize + liveSet@ upvalues,
and Lua 5.1 caps a function at 60 upvalues (@LUAI_MAXUPVALUES@).
-}
maxLiveSet ∷ Int
maxLiveSet = 15
