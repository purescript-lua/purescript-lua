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

== Behaviour preservation

PUC's tail-call optimization already guarantees O(1) stack for the
rewritten shapes, so the transform changes constants, not semantics;
the one observable difference is the shape of error tracebacks. The
transform runs during code generation on bindings that come from IR
recursive groups only — foreign (hand-written) Lua never passes
through it.
-}
module Language.PureScript.Backend.Lua.Loopify
  ( Self (..)
  , loopify
  ) where

import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Set qualified as Set
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Types
  ( Annotated
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
  case rewriteBlock self carried body of
    (body', Loopified) →
      pure $ Function params [ann (While (ann (Boolean True)) body')]
    (_, NotLoopified) → Nothing

--------------------------------------------------------------------------------
-- Tail self-call rewriting ----------------------------------------------------

data Loopified = Loopified | NotLoopified

instance Semigroup Loopified where
  NotLoopified <> NotLoopified = NotLoopified
  _ <> _ = Loopified

-- | Rewrite the tail position of a block: its final statement.
rewriteBlock ∷ Self → NonEmpty Name → Block → (Block, Loopified)
rewriteBlock self carried block = case List.unsnoc block of
  Nothing → (block, NotLoopified)
  Just (leading, (comments, final)) →
    let (final', looped) = rewriteFinal self carried final
     in (leading <> [(comments, final')], looped)

rewriteFinal
  ∷ Self
  → NonEmpty Name
  → StatementF Comments
  → (StatementF Comments, Loopified)
rewriteFinal self carried = \case
  original@(Return [Ann (FunctionCall (Ann callee) args)])
    | isSelfCallee self callee →
        case balanceExplist (length carried) args of
          Just explist →
            (Assign (ann . VarName <$> carried) explist, Loopified)
          Nothing → (original, NotLoopified)
  IfThenElse predicate thenBlock elseBlock →
    let (thenBlock', loopedThen) = rewriteBlock self carried thenBlock
        (elseBlock', loopedElse) = rewriteBlock self carried elseBlock
     in (IfThenElse predicate thenBlock' elseBlock', loopedThen <> loopedElse)
  statement → (statement, NotLoopified)

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
