{- | Loopification of self-recursive tail calls (issue #181).

A self-recursive tail call stays a call after the uncurrying
worker/wrapper split ("Language.PureScript.Backend.IR.Uncurry"). PUC
Lua's tail-call optimization already reuses the frame, so recursion is
not a stack-safety problem — but it pays CALL\/RET machinery and
argument shuffling on every iteration, and under LuaJIT a hot recursive
worker lacks the stable loop marker the trace compiler wants. A real
@while true do@ loop is the canonically better shape: it gets a loop
trace, loop-invariant hoisting, and one frame for the whole run.

== The transform

A function assigned to a recursive-group binding

> f = function(p₁, …, pₖ)
>   …
>   return f(e₁, …, eₘ)  -- tail self-call
>   …
>   return r             -- any other exit
> end

becomes

> f = function(p₁, …, pₖ)
>   while true do
>     …
>     p₁, …, pₖ = e₁, …, eₘ  -- the tail self-call, now an iteration
>     …
>     return r               -- other exits return as before
>   end
> end

The rewritten call is a /tail/ self-call: a block-final @return@ whose
callee is the binding's own name, found by walking the block spine —
the last statement of the body and, recursively, the last statement of
each branch of a block-final @if@. This is exactly where the Lua
code generator ("Language.PureScript.Backend.Lua") puts the IR tail
positions (through 'Language.PureScript.Backend.IR.Types.Let' bodies
and 'Language.PureScript.Backend.IR.Types.IfThenElse' branches), and a
replaced @return@ leaves its enclosing blocks falling through straight
to the end of the loop body — Lua 5.1 has no @goto@, so loopification
relies on this fall-through for "continue". Every other exit path still
@return@s, which leaves the loop. Non-tail self-calls (and the curried
wrapper's delegation) are left alone: each such call starts a fresh
activation with its own loop, which is exactly the semantics it had.

Lua's multiple assignment gives the parameter swap simultaneity for
free: the right-hand explist is fully evaluated against the current
parameter values before any variable is reassigned, with the same
value adjustment a call performs on its arguments. The two lists can
still disagree in length, because the code generator drops a trailing
run of unused parameters (the call may then pass more values than
there are variables) and trailing @Prim.undefined@ arguments (fewer)
— see Note [Nullary functions and Prim.undefined]. Rather than emit
an unbalanced assignment (semantically fine, but flagged by luacheck),
the explist is balanced to the variable count: a short list is padded
with explicit @nil@s (what the call would bind — declined when the
last argument is a call or vararg, whose multiple results the pad
would truncate where the call form spreads them), and surplus
expressions are dropped when they are syntactically pure (a literal, a
plain variable, a function literal — a value in a dropped-parameter
position is never consumed, so only its evaluation effects matter).
A self-call that cannot be balanced is left a real tail call.

== The capture veto

Lua closures capture variables by reference. Parameters of a loopified
function are shared across all iterations, while a fresh activation
per call gives every iteration its own; a closure created in one
iteration and surviving into the next (e.g. a CPS-style accumulator
@go (n - 1) (\\r → k (r + n))@) would observe the reassigned values.
Therefore a function whose body references a parameter from inside a
nested @function@ literal is not loopified. An immediately-invoked
zero-argument function — @(function() … end)()@, the code generator's
expression-position scope wrapper — runs within the iteration that
created it, so the analysis looks through it transparently; any
other function literal is treated as escaping. Local variables need
no veto: their @local@ declarations sit inside the loop body and are
re-created each iteration.

The veto errs conservatively (a captured parameter name is assumed to
escape even where a human could prove it does not), which only costs
an optimization opportunity, never correctness.

== Mutual recursion (issue #234)

'loopify' rewrites self-calls only, so a group of functions that
tail-call /each other/ keeps paying a call per transition. The members
of every tail-call cycle lower instead to one dispatcher function

> f₁$loop = function(sel, s₁, …, sₖ)
>   while true do
>     if sel == 1 then
>       local p₁, … = s₁, …          -- member 1's parameters
>       …                            -- member 1's body, where a tail
>       sel, s₁, …, sₖ = 2, e₁, …    -- call of member 2 became this
>     else
>       …
>     end
>   end
> end

over a branch selector plus shared argument slots (one per parameter
of the widest member), while the member bindings survive as entry
wrappers @f₁ = function(p₁, …) return f₁$loop(1, p₁, …) end@. A cycle
is a strongly-connected component of size two or more of the /spine
tail-call graph/: member X has an edge to member Y when X's body tail-
calls Y at the block spine ('planGroupDispatch'). Self-calls of a cycle
member become same-branch transitions of the shared dispatcher.

Because the bindings survive as wrappers, every other reference stays
valid without any use analysis: a non-tail use inside the group, an
uncurrying wrapper left in the group (which references the worker from
under a nested lambda and therefore never joins a cycle), an external
caller, an export. The uniform-tail-call test is thereby a
profitability criterion, not a soundness precondition — a transition
whose explist cannot be balanced simply stays a real call, now landing
on the callee's entry wrapper.

The dispatcher needs no capture veto: each branch rebinds its member's
parameters as loop-body locals, re-created every iteration, so a
closure captures per-iteration bindings exactly as a fresh activation
would provide. Only the selector and the slots are shared across
iterations, and their names are minted fresh by the code generator —
no user code can reference them. A member whose body can fall off its
end (a value-less native-loop chunk) is excluded: falling through a
dispatcher branch would iterate the loop instead of returning nil
('exitTotal').

== Join points (issue #234)

A chunk-local helper only ever tail-called from the chunk's spine is a
loop in disguise, but compiles as a function plus an entry call per
use. 'joinifyChunk' removes the shell:

> local k = function(p₁, …, pₘ) K end
> …
> return k(e₁, …, eₘ)   -- every use: a spine-final tail call
> …
> return r              -- any other exit

becomes

> local p₁, …, pₘ       -- the parameters, hoisted in place of k
> …
> p₁, …, pₘ = e₁, …, eₘ -- each entry: assign and fall through
> …
> return r
> K                     -- the helper's body ends the chunk

Every path through the rewritten prefix either @return@s (leaving the
function before reaching K) or has assigned the parameters and falls
through into K, whose own exits @return@ as before. A self-recursive
helper arrives here already loopified — its body is the @while true@
loop, all self-calls gone — so the fusion composes: entry assignments
fall into the loop. The transform iterates until no candidate fuses;
a helper whose only entries sit in a just-appended body fuses in the
next round, so chains of join points flatten completely.

The transform commits only when it can account for every use of the
helper: after rewriting, no read of its name may remain anywhere in
the chunk (a reference from a nested closure, an argument position, a
non-spine call — any survivor vetoes), at least one entry must have
been rewritten, the chunk's spine leaves must all be @return@s both
before (no falling off the chunk's end into K) and, calls excepted,
after the rewrite. That last condition — no remaining spine leaf may
@return@ a bare call — is deliberate conservatism: this transform runs
before 'loopify' sees the enclosing binding, and burying a potential
tail self-call mid-chunk would rob the enclosing loopification (or a
mutual-dispatch cycle) of its tail position.

No capture veto is needed: the hoisted parameters are locals of the
chunk, re-created per activation (and per iteration once an enclosing
@while true@ wraps the chunk), and at most one entry executes per
chunk run — exactly the one activation the helper had as a function.

== Behaviour preservation

PUC's tail-call optimization already guarantees O(1) stack for the
rewritten shapes, so the transforms change constants, not semantics;
the one observable difference is the shape of error tracebacks. All
three transforms run during code generation on IR-derived code only —
foreign (hand-written) Lua never passes through them.
-}
module Language.PureScript.Backend.Lua.Loopify
  ( Self (..)
  , selfName
  , loopify
  , DispatchGroup (..)
  , DispatchMember (..)
  , planGroupDispatch
  , emitDispatchGroup
  , joinifyChunk
  ) where

import Data.Graph qualified as Graph
import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Set qualified as Set
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Types
  ( Annotated
  , BinaryOp (EqualTo)
  , Comments
  , Exp
  , ExpF (..)
  , ParamF (..)
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  , ann
  , unAnn
  , pattern Ann
  )
import Prelude

{- | How a self-reference of the binding under rewrite renders in Lua:
a plain local variable (a 'Language.PureScript.Backend.IR.Types.Let'
recursive group), or a field of the module-scope table (a top-level
recursive group).
-}
data Self
  = SelfLocal Name
  | SelfField Name Name

-- | The binding's own name: the local, or the field of the scope table.
selfName ∷ Self → Name
selfName = \case
  SelfLocal name → name
  SelfField _table field → field

type Block = [Annotated Comments StatementF]

{- | Rewrite the tail self-calls of a recursive binding's function into
iterations of a @while true do@ loop. Returns the expression unchanged
when it is not a function, has no rewritable tail self-call, or the
capture veto applies.
-}
loopify ∷ Self → Exp → Exp
loopify self original = fromMaybe original do
  Function params body ← pure original
  carried ← NE.nonEmpty =<< traverse (paramNamed . unAnn) params
  guard $
    Set.disjoint
      (Set.fromList (toList carried))
      (closureRefs BodyLevel body)
  case rewriteSpine (selfCallRewrite self carried) body of
    (body', Loopified) →
      pure $ Function params [ann (While (ann (Boolean True)) body')]
    (_, NotLoopified) → Nothing

--------------------------------------------------------------------------------
-- Tail-call rewriting ---------------------------------------------------------

data Loopified = Loopified | NotLoopified

instance Semigroup Loopified where
  NotLoopified <> NotLoopified = NotLoopified
  _ <> _ = Loopified

{- | A rewrite applied at the spine positions of a block: 'Just'
replaces the statement (counting as 'Loopified'), 'Nothing' leaves it
alone.
-}
type SpineRewrite = StatementF Comments → Maybe (StatementF Comments)

-- | Rewrite the tail position of a block: its final statement.
rewriteSpine ∷ SpineRewrite → Block → (Block, Loopified)
rewriteSpine rewrite block = case List.unsnoc block of
  Nothing → (block, NotLoopified)
  Just (leading, (comments, final)) →
    let (final', looped) = rewriteFinal rewrite final
     in (leading <> [(comments, final')], looped)

rewriteFinal
  ∷ SpineRewrite → StatementF Comments → (StatementF Comments, Loopified)
rewriteFinal rewrite statement
  | Just statement' ← rewrite statement = (statement', Loopified)
  | IfThenElse predicate thenBlock elseBlock ← statement =
      let (thenBlock', loopedThen) = rewriteSpine rewrite thenBlock
          (elseBlock', loopedElse) = rewriteSpine rewrite elseBlock
       in (IfThenElse predicate thenBlock' elseBlock', loopedThen <> loopedElse)
  | otherwise = (statement, NotLoopified)

{- | Replace a tail self-call with the simultaneous reassignment of the
carried parameters. A self-call whose explist cannot be balanced is
left a real tail call.
-}
selfCallRewrite ∷ Self → NonEmpty Name → SpineRewrite
selfCallRewrite self carried = \case
  Return [Ann (FunctionCall (Ann callee) args)]
    | isSelfCallee self callee →
        Assign (ann . VarName <$> carried)
          <$> balanceExplist (length carried) args
  _ → Nothing

{- | Balance the self-call's argument explist against the count of
assigned variables — see the module documentation. 'Nothing' declines
the rewrite.
-}
balanceExplist
  ∷ Int
  → [Annotated Comments ExpF]
  → Maybe (NonEmpty (Annotated Comments ExpF))
balanceExplist varCount args = case compare (length args) varCount of
  EQ → NE.nonEmpty args
  LT → do
    -- Padding after a multi-value expression would truncate it to one
    -- value where the call form spreads all of them.
    whenJust (viaNonEmpty last args) (guard . singleValued . unAnn)
    NE.nonEmpty (args <> replicate (varCount - length args) (ann Nil))
  GT → do
    let (kept, surplus) = splitAt varCount args
    guard (all (syntacticallyPure . unAnn) surplus)
    NE.nonEmpty kept

-- | Adjusted to exactly one value in any explist position.
singleValued ∷ ExpF Comments → Bool
singleValued = \case
  FunctionCall {} → False
  MethodCall {} → False
  Vararg → False
  _ → True

{- | Free of evaluation effects, so an unconsumed occurrence can be
dropped: no calls (and no table constructors or index chains, which
can run metamethods).
-}
syntacticallyPure ∷ ExpF Comments → Bool
syntacticallyPure = \case
  Nil → True
  Boolean _ → True
  Integer _ → True
  Float _ → True
  String _ → True
  Function _params _body → True
  Var (Ann (VarName _)) → True
  Paren e → syntacticallyPure (unAnn e)
  _ → False

isSelfCallee ∷ Self → ExpF Comments → Bool
isSelfCallee self callee = case (self, callee) of
  (SelfLocal name, Var (Ann (VarName n))) →
    n == name
  ( SelfField table field
    , Var (Ann (VarField (Ann (Var (Ann (VarName t)))) f))
    ) →
      t == table && f == field
  _ → False

--------------------------------------------------------------------------------
-- Mutual-recursion dispatch ---------------------------------------------------

{- | One dispatchable tail-call cycle of a recursive group — see the
mutual-recursion section of the module documentation.
-}
data DispatchGroup = DispatchGroup
  { dispatchMembers ∷ NonEmpty DispatchMember
  -- ^ the cycle's members, in original group order
  , dispatchArity ∷ Int
  -- ^ shared slot count: the widest member's parameter count
  }

data DispatchMember = DispatchMember
  { dispatchIndex ∷ Int
  -- ^ the member's position in the original group (0-based)
  , dispatchSelf ∷ Self
  -- ^ how the member's own name renders in Lua
  , dispatchParams ∷ [Name]
  -- ^ the member function's parameters
  , dispatchBody ∷ Block
  -- ^ the member function's body
  }

{- | The tail-call cycles of a compiled recursive group: the strongly-
connected components (of size two or more) of the spine tail-call graph
over the group's function members. Members outside every cycle — non-
functions, uncurrying wrappers (their group references sit under nested
lambdas, never at the spine), functions with unused\/vararg parameters,
bodies that can fall off their end — are left for the per-member
'loopify'.
-}
planGroupDispatch ∷ [(Self, Exp)] → [DispatchGroup]
planGroupDispatch members = mapMaybe dispatchable sccs
 where
  candidates ∷ [DispatchMember]
  candidates =
    [ DispatchMember index self params body
    | (index, (self, expr)) ← zip [0 ..] members
    , Function annotatedParams body ← [expr]
    , exitTotal body
    , Just params ← [traverse (paramNamed . unAnn) annotatedParams]
    ]
  candidateIndex ∷ ExpF Comments → Maybe Int
  candidateIndex callee =
    listToMaybe
      [dispatchIndex m | m ← candidates, isSelfCallee (dispatchSelf m) callee]
  sccs =
    Graph.stronglyConnComp
      [ (m, dispatchIndex m, spineCallees candidateIndex (dispatchBody m))
      | m ← candidates
      ]
  dispatchable = \case
    Graph.CyclicSCC cycleMembers@(_ : _ : _) →
      let ordered = sortOn dispatchIndex cycleMembers
       in Just
            DispatchGroup
              { dispatchMembers = NE.fromList ordered
              , dispatchArity =
                  foldr (max . length . dispatchParams) 0 ordered
              }
    _ → Nothing

{- | Lower one tail-call cycle to its dispatcher function and the entry
wrappers replacing the member bindings. The caller mints the selector
and slot names (fresh, so no user code can reference them) and decides
how the dispatcher itself is bound.
-}
emitDispatchGroup
  ∷ Self
  -- ^ how the dispatcher renders (for the wrappers' delegation call)
  → Name
  -- ^ branch-selector parameter
  → [Name]
  -- ^ shared argument slots, 'dispatchArity' of them
  → DispatchGroup
  → (Exp, [(Int, Exp)])
  {- ^ the dispatcher function, and the entry wrapper for each member
  keyed by its original group index
  -}
emitDispatchGroup dispatcher selector slots DispatchGroup {dispatchMembers} =
  (dispatcherFunction, wrappers)
 where
  variables ∷ NonEmpty Name
  variables = selector :| slots

  branches ∷ NonEmpty (Integer, DispatchMember)
  branches = NE.zip (1 :| [2 ..]) dispatchMembers

  branchIndex ∷ ExpF Comments → Maybe Integer
  branchIndex callee =
    listToMaybe
      [j | (j, m) ← toList branches, isSelfCallee (dispatchSelf m) callee]

  -- A spine tail call of a cycle member becomes the simultaneous
  -- assignment of the selector and the slots; the balancing rules of
  -- 'balanceExplist' carry over with the selector literal prepended.
  transitionRewrite ∷ SpineRewrite
  transitionRewrite = \case
    Return [Ann (FunctionCall (Ann callee) args)]
      | Just j ← branchIndex callee →
          Assign (ann . VarName <$> variables)
            <$> balanceExplist (length variables) (ann (Integer j) : args)
    _ → Nothing

  branchBody ∷ DispatchMember → Block
  branchBody DispatchMember {dispatchParams, dispatchBody} =
    rebind <> body
   where
    rebind = case NE.nonEmpty dispatchParams of
      Nothing → []
      Just params →
        [ ann . Local params $
            take (length dispatchParams) (ann . Var . ann . VarName <$> slots)
        ]
    (body, _looped) = rewriteSpine transitionRewrite dispatchBody

  -- @if sel == 1 then … else[if …] …@ — the last branch needs no test.
  branchChain ∷ NonEmpty (Integer, DispatchMember) → Block
  branchChain ((j, m) :| rest) = case rest of
    [] → branchBody m
    next : more →
      [ ann $
          IfThenElse
            ( ann $
                BinOp
                  EqualTo
                  (ann (Var (ann (VarName selector))))
                  (ann (Integer j))
            )
            (branchBody m)
            (branchChain (next :| more))
      ]

  dispatcherFunction ∷ Exp
  dispatcherFunction =
    Function
      (ann . ParamNamed <$> toList variables)
      [ann (While (ann (Boolean True)) (branchChain branches))]

  wrappers ∷ [(Int, Exp)]
  wrappers =
    [ ( dispatchIndex m
      , Function
          (ann . ParamNamed <$> dispatchParams m)
          [ ann . Return . pure . ann $
              FunctionCall
                (ann (selfExp dispatcher))
                ( ann (Integer j)
                    : (ann . Var . ann . VarName <$> dispatchParams m)
                )
          ]
      )
    | (j, m) ← toList branches
    ]

-- | The expression a 'Self' reads as.
selfExp ∷ Self → ExpF Comments
selfExp = \case
  SelfLocal name → Var (ann (VarName name))
  SelfField table field →
    Var (ann (VarField (ann (Var (ann (VarName table)))) field))

-- | The original-group indices of members tail-called at the block spine.
spineCallees ∷ (ExpF Comments → Maybe Int) → Block → [Int]
spineCallees calleeIndex block = case List.unsnoc block of
  Nothing → []
  Just (_leading, (_comments, final)) → finalCallees final
 where
  finalCallees = \case
    Return [Ann (FunctionCall (Ann callee) _args)] →
      maybeToList (calleeIndex callee)
    IfThenElse _predicate thenBlock elseBlock →
      spineCallees calleeIndex thenBlock <> spineCallees calleeIndex elseBlock
    _ → []

{- | Control can never fall off the block's end: every spine leaf is a
@return@ (recursing through final @if@ branches), or a @while true@
loop no @break@ escapes — a loopified body's shape, which exits through
its internal @return@s only. Bodies failing this — a value-less
native-loop chunk is the one shape the code generator emits — must not
become dispatcher branches or appended join-point bodies: reaching
their end would iterate the enclosing dispatcher loop (or run whatever
follows) instead of returning nil.
-}
exitTotal ∷ Block → Bool
exitTotal block = case List.unsnoc block of
  Nothing → False
  Just (_leading, (_comments, final)) → case final of
    Return _ → True
    IfThenElse _predicate thenBlock elseBlock →
      exitTotal thenBlock && exitTotal elseBlock
    While (Ann (Boolean True)) body → not (loopLevelBreak body)
    _ → False

{- | Whether the block has a @break@ binding to the loop enclosing it —
one not nested inside a loop of the block's own.
-}
loopLevelBreak ∷ Block → Bool
loopLevelBreak = any (breaks . unAnn)
 where
  breaks = \case
    Break → True
    IfThenElse _predicate thenBlock elseBlock →
      loopLevelBreak thenBlock || loopLevelBreak elseBlock
    Do block → loopLevelBreak block
    -- A break inside a nested loop binds to that loop.
    While _ _ → False
    Repeat _ _ → False
    ForNum {} → False
    ForIn {} → False
    _ → False

--------------------------------------------------------------------------------
-- Join points -----------------------------------------------------------------

{- | Fuse the chunk's join points — see the join-points section of the
module documentation. Applied by the code generator wherever a compiled
chunk is finalized into a function body or a scope call.
-}
joinifyChunk ∷ [StatementF Comments] → [StatementF Comments]
joinifyChunk chunk = unAnn <$> joinify (ann <$> chunk)

-- Iterates until no candidate fuses: each committed fusion removes one
-- function literal, so the iteration terminates.
joinify ∷ Block → Block
joinify block =
  maybe block joinify (asum (tryJoin block <$> joinCandidates block))

{- | A helper eligible for fusion: a chunk-level @local k = function@
(or the forward-declaration\/assignment pair a recursive group
compiles to), with named parameters and a body control cannot fall out
of.
-}
data JoinCandidate = JoinCandidate
  { joinName ∷ Name
  , joinParams ∷ NonEmpty Name
  , joinBody ∷ Block
  , joinDeclIndex ∷ Int
  -- ^ where the parameters hoist: the candidate's declaration statement
  , joinAssignIndex ∷ Maybe Int
  -- ^ the separate assignment of a forward-declared candidate
  }

joinCandidates ∷ Block → [JoinCandidate]
joinCandidates block = mapMaybe candidateAt indexed
 where
  indexed = zip [0 ..] (unAnn <$> block)
  candidateAt (index, statement) = case statement of
    Local (name :| []) [Ann (Function annotatedParams body)] → do
      params ← functionParams annotatedParams body
      Just
        JoinCandidate
          { joinName = name
          , joinParams = params
          , joinBody = body
          , joinDeclIndex = index
          , joinAssignIndex = Nothing
          }
    Assign
      (Ann (VarName name) :| [])
      (Ann (Function annotatedParams body) :| []) → do
        params ← functionParams annotatedParams body
        declIndex ←
          listToMaybe
            [ j
            | (j, Local (declared :| []) []) ← indexed
            , declared == name
            ]
        Just
          JoinCandidate
            { joinName = name
            , joinParams = params
            , joinBody = body
            , joinDeclIndex = declIndex
            , joinAssignIndex = Just index
            }
    _ → Nothing
  functionParams annotatedParams body = do
    params ← NE.nonEmpty =<< traverse (paramNamed . unAnn) annotatedParams
    params <$ guard (exitTotal body)

-- | Fuse one candidate, or decline — see the module documentation.
tryJoin ∷ Block → JoinCandidate → Maybe Block
tryJoin block candidate = do
  let withoutDef = flip mapMaybe (zip [0 ..] block) \(index, statement) →
        if
          | index == joinDeclIndex candidate →
              Just (ann (Local (joinParams candidate) []))
          | Just index == joinAssignIndex candidate → Nothing
          | otherwise → Just statement
  -- No falling off the chunk's end into the appended body.
  guard (exitTotal withoutDef)
  case rewriteSpine
    (selfCallRewrite (SelfLocal (joinName candidate)) (joinParams candidate))
    withoutDef of
    (_, NotLoopified) → Nothing
    (rewritten, Loopified) → do
      -- Burying a spine tail call would rob the enclosing binding's
      -- loopification of it.
      guard (not (spineReturnsCall rewritten))
      -- Every use must be gone — any surviving read vetoes the fusion.
      guard (nameReads (joinName candidate) rewritten == 0)
      pure (rewritten <> joinBody candidate)

-- | Whether any spine leaf returns a bare call.
spineReturnsCall ∷ Block → Bool
spineReturnsCall block = case List.unsnoc block of
  Nothing → False
  Just (_leading, (_comments, final)) → case final of
    Return [Ann FunctionCall {}] → True
    IfThenElse _predicate thenBlock elseBlock →
      spineReturnsCall thenBlock || spineReturnsCall elseBlock
    _ → False

{- | How many times the name is read anywhere in the block — every
position counts, including nested closures (unlike 'closureRefs', which
implements the capture veto and is position-sensitive). Bare assignment
targets are writes, not reads; binders never collide with the searched
name under global uniqueness of compiled names.
-}
nameReads ∷ Name → Block → Int
nameReads name = readsInBlock
 where
  readsInBlock ∷ Block → Int
  readsInBlock = sum . fmap (readsInStatement . unAnn)

  readsInStatement ∷ StatementF Comments → Int
  readsInStatement = \case
    Assign vars vals →
      sum (readsInWrite . unAnn <$> vars)
        + sum (readsInExp . unAnn <$> vals)
    Local _names vals → sum (readsInExp . unAnn <$> vals)
    IfThenElse predicate thenBlock elseBlock →
      readsInExp (unAnn predicate)
        + readsInBlock thenBlock
        + readsInBlock elseBlock
    Return exps → sum (readsInExp . unAnn <$> exps)
    CallStatement e → readsInExp (unAnn e)
    Do block → readsInBlock block
    While predicate block →
      readsInExp (unAnn predicate) + readsInBlock block
    Repeat block predicate →
      readsInBlock block + readsInExp (unAnn predicate)
    ForNum _name start limit step block →
      readsInExp (unAnn start)
        + readsInExp (unAnn limit)
        + sum (readsInExp . unAnn <$> step)
        + readsInBlock block
    ForIn _names exps block →
      sum (readsInExp . unAnn <$> exps) + readsInBlock block
    LocalFunction _name _params block → readsInBlock block
    Break → 0

  readsInExp ∷ ExpF Comments → Int
  readsInExp = \case
    Function _params block → readsInBlock block
    Var (Ann v) → readsInRead v
    FunctionCall fn args →
      readsInExp (unAnn fn) + sum (readsInExp . unAnn <$> args)
    MethodCall obj _name args →
      readsInExp (unAnn obj) + sum (readsInExp . unAnn <$> args)
    TableCtor rows → sum (readsInRow . unAnn <$> rows)
    UnOp _op e → readsInExp (unAnn e)
    BinOp _op e1 e2 → readsInExp (unAnn e1) + readsInExp (unAnn e2)
    Paren e → readsInExp (unAnn e)
    Nil → 0
    Boolean _ → 0
    Integer _ → 0
    Float _ → 0
    String _ → 0
    Vararg → 0

  readsInRow ∷ TableRowF Comments → Int
  readsInRow = \case
    TableRowKV k v → readsInExp (unAnn k) + readsInExp (unAnn v)
    TableRowNV _name v → readsInExp (unAnn v)
    TableRowV v → readsInExp (unAnn v)

  -- A bare name as an assignment target is a write.
  readsInWrite ∷ VarF Comments → Int
  readsInWrite = \case
    VarName _ → 0
    VarIndex e1 e2 → readsInExp (unAnn e1) + readsInExp (unAnn e2)
    VarField e _name → readsInExp (unAnn e)

  readsInRead ∷ VarF Comments → Int
  readsInRead = \case
    VarName n → if n == name then 1 else 0
    VarIndex e1 e2 → readsInExp (unAnn e1) + readsInExp (unAnn e2)
    VarField e _name → readsInExp (unAnn e)

--------------------------------------------------------------------------------
-- Capture analysis ------------------------------------------------------------

{- | Whether the code being walked runs within the current activation
('BodyLevel') or inside a nested closure that may outlive it
('UnderClosure').
-}
data Position = BodyLevel | UnderClosure

{- | The names referenced from inside nested closures of a block. At
'BodyLevel' plain references are invisible (reading a parameter within
the iteration is fine); crossing into a function literal makes every
name beneath it count. An immediately-invoked zero-argument function
is looked through transparently — see the capture veto section of the
module documentation.
-}
closureRefs ∷ Position → Block → Set Name
closureRefs pos = foldMap (refsInStatement pos . unAnn)

refsInStatement ∷ Position → StatementF Comments → Set Name
refsInStatement pos = \case
  Assign vars vals →
    foldMap (refsInVar pos . unAnn) vars
      <> foldMap (refsInExp pos . unAnn) vals
  Local _names vals → foldMap (refsInExp pos . unAnn) vals
  IfThenElse predicate thenBlock elseBlock →
    refsInExp pos (unAnn predicate)
      <> closureRefs pos thenBlock
      <> closureRefs pos elseBlock
  Return exps → foldMap (refsInExp pos . unAnn) exps
  CallStatement e → refsInExp pos (unAnn e)
  Do block → closureRefs pos block
  While predicate block →
    refsInExp pos (unAnn predicate) <> closureRefs pos block
  Repeat block predicate →
    closureRefs pos block <> refsInExp pos (unAnn predicate)
  ForNum _name start limit step block →
    refsInExp pos (unAnn start)
      <> refsInExp pos (unAnn limit)
      <> foldMap (refsInExp pos . unAnn) step
      <> closureRefs pos block
  ForIn _names exps block →
    foldMap (refsInExp pos . unAnn) exps <> closureRefs pos block
  LocalFunction _name _params block → closureRefs UnderClosure block
  Break → mempty

refsInExp ∷ Position → ExpF Comments → Set Name
refsInExp pos = \case
  -- An immediately-invoked scope wrapper runs where it stands:
  FunctionCall (Ann (Function [] block)) [] → closureRefs pos block
  Function _params block → closureRefs UnderClosure block
  Var (Ann v) → refsInVar pos v
  FunctionCall fn args →
    refsInExp pos (unAnn fn) <> foldMap (refsInExp pos . unAnn) args
  MethodCall obj _name args →
    refsInExp pos (unAnn obj) <> foldMap (refsInExp pos . unAnn) args
  TableCtor rows → foldMap (refsInRow pos . unAnn) rows
  UnOp _op e → refsInExp pos (unAnn e)
  BinOp _op e1 e2 → refsInExp pos (unAnn e1) <> refsInExp pos (unAnn e2)
  Paren e → refsInExp pos (unAnn e)
  Nil → mempty
  Boolean _ → mempty
  Integer _ → mempty
  Float _ → mempty
  String _ → mempty
  Vararg → mempty

refsInRow ∷ Position → TableRowF Comments → Set Name
refsInRow pos = \case
  TableRowKV k v → refsInExp pos (unAnn k) <> refsInExp pos (unAnn v)
  TableRowNV _name v → refsInExp pos (unAnn v)
  TableRowV v → refsInExp pos (unAnn v)

refsInVar ∷ Position → VarF Comments → Set Name
refsInVar pos = \case
  VarName name → case pos of
    UnderClosure → Set.singleton name
    BodyLevel → mempty
  VarIndex e1 e2 → refsInExp pos (unAnn e1) <> refsInExp pos (unAnn e2)
  VarField e _name → refsInExp pos (unAnn e)

--------------------------------------------------------------------------------
-- Helper Functions ------------------------------------------------------------

paramNamed ∷ ParamF Comments → Maybe Name
paramNamed = \case
  ParamNamed name → Just name
  ParamUnused → Nothing
  ParamVararg → Nothing
