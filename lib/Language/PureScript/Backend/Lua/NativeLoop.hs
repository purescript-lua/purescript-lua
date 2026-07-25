{- | Lower Effect/ST loop combinators to native Lua loops (issue #233).

An @Effect@/@ST@ loop otherwise stays a call into a foreign higher-order
combinator: @foreachE arr f@ compiles to a foreign function handed a Lua
closure that it calls once per iteration — one closure allocation and one
call per step, on top of the combinator's own call. Magic-do flattens the
surrounding bind chain but never touches the loop itself. Lowered at
codegen time the combinators become the loops their foreign
implementations run:

  * @foreachE arr f@   → @for i = 1, #arr do … end@
  * @forE lo hi f@     → @for i = lo, hi - 1 do … end@ (PureScript's
    @forE@ iterates the half-open @[lo, hi)@)
  * @whileE cond body@ → @while … do … end@

with the body lambda inlined as the loop body and its parameter as the
loop variable, so both the per-iteration closure and the foreign call
disappear.

== Recognition

A lowering candidate is a saturated application of a known combinator
/run/ by magic-do — the application spine ends in 'IR.EffectRunArg'.
Recognition is by qualified name, the same identity magic-do matches
chain heads by (Note [Canonical Effect/ST heads]): the six combinators
of the @Effect@ and @Control.Monad.ST.Internal@ modules, in either of
the two forms a foreign reference takes at codegen time — the plain
imported reference and the dissolved foreign-accessor read
('foreignAccessorQName'). A user-defined combinator that shares a name
lives in a different module and never matches; an unrecognised or
unsaturated shape falls through to the ordinary call, which is always
sound — the foreign implementation remains in place.

Only a /run/ lowers. A loop application without 'IR.EffectRunArg' — a
first-class @foreachE arr f@ passed around as a value — compiles to the
foreign call as before.

Known limitation: unlike magic-do's chain-head recognition, which
resolves one hop through a top-level alias
('Language.PureScript.Backend.IR.MagicDo.isCanonicalHead'), this matcher
resolves none. The optimizer dissolves a bare-'Ref' alias to a
combinator before code generation, so ordinary code is unaffected; an
@inline never@ directive pinning such an alias undissolved leaves the
foreign call in place — a missed optimization, never a miscompile, since
the foreign implementation is what stays. @Golden.NativeLoopsAliasPin@
pins that shape. Threading a resolver in here would close it, but
recognition is due to move into the IR (issue #239 needs the loop
visible to the optimizer, which a codegen-time match cannot provide),
and the alias question disappears once a lift keys off the foreign
import itself.

== Evaluation order and sharing

The foreign combinator receives its arguments evaluated once, in
application order. The lowering preserves both: a non-atomic argument
that the emitted loop would otherwise re-evaluate per iteration (the
array indexed in the body, a pre-built body function called per step)
is bound to a fresh local first ('atomize'), and the pre-bindings are
emitted in application order. A run of pre-bindings is wrapped in a
@do … end@ block together with its loop so the temporaries die with the
loop — magic-do budgets ~150 @local@s per function
('Language.PureScript.Backend.IR.MagicDo.chunkSize'), and unscoped
temporaries on every loop statement could breach Lua's @LUAI_MAXVARS@
(200 active locals).

== Inlining the body

Running an Effect/ST value for its effect ('runStatements') has two
shapes. A literal thunk @\\_ → inner@ runs as @inner@ itself — the
statements of its compiled chunk, with tail 'Lua.Return's rewritten to
evaluation statements ('statementize'), since the run discards the
value. Anything else runs as the call @e()@. One guard: a thunk chunk
declaring more than 'spliceLocalBudget' block-level locals is not
spliced — the enclosing function already holds up to a magic-do chunk's
~150 locals, and splicing a similarly sized block would overflow
@LUAI_MAXVARS@ — such a body keeps the per-iteration thunk call, which
is exactly the cost the foreign implementation had.
-}
module Language.PureScript.Backend.Lua.NativeLoop
  ( NativeLoop
  , matchLoopRun
  , lowerLoop
  ) where

import Data.Map.Strict qualified as Map
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Linker (foreignAccessorQName)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Types qualified as Lua

--------------------------------------------------------------------------------
-- Recognition -----------------------------------------------------------------

{- | A recognised loop-combinator run, carrying the combinator's IR
arguments.
-}
data NativeLoop
  = -- | @foreachE arr f@: the array and the per-element function.
    ForeachLoop IR.Exp IR.Exp
  | -- | @forE lo hi f@: the half-open bounds and the per-index function.
    ForRangeLoop IR.Exp IR.Exp IR.Exp
  | -- | @whileE cond body@: the condition and body computations.
    WhileLoop IR.Exp IR.Exp

data LoopKind = ForeachKind | ForRangeKind | WhileKind

{- | The known loop combinators, keyed by the qualified name recognition
matches on (see the module haddock).
-}
loopCombinators ∷ Map IR.QName LoopKind
loopCombinators =
  Map.fromList
    [ (IR.QName effectModule (IR.Name "foreachE"), ForeachKind)
    , (IR.QName effectModule (IR.Name "forE"), ForRangeKind)
    , (IR.QName effectModule (IR.Name "whileE"), WhileKind)
    , (IR.QName stModule (IR.Name "foreach"), ForeachKind)
    , (IR.QName stModule (IR.Name "for"), ForRangeKind)
    , (IR.QName stModule (IR.Name "while"), WhileKind)
    ]
 where
  effectModule = IR.ModuleName "Effect"
  stModule = IR.ModuleName "Control.Monad.ST.Internal"

{- | Recognise the run of a saturated loop-combinator application:
@combinator a₁ … aₙ EffectRunArg@ with the combinator's exact arity.
-}
matchLoopRun ∷ IR.Exp → Maybe NativeLoop
matchLoopRun = \case
  IR.AppN _ann fn (IR.EffectRunArg _ :| []) → do
    let (hd, args) = IR.unwindApp fn
    kind ← (`Map.lookup` loopCombinators) =<< headQName hd
    case (kind, args) of
      (ForeachKind, [arr, f]) → Just (ForeachLoop arr f)
      (ForRangeKind, [lo, hi, f]) → Just (ForRangeLoop lo hi f)
      (WhileKind, [cond, body]) → Just (WhileLoop cond body)
      _ → Nothing
  _ → Nothing

{- | The qualified name a combinator head denotes: a plain imported
reference, or the dissolved foreign-accessor read (the two forms of
'Language.PureScript.Backend.IR.MagicDo.headQName' that occur without
an alias hop).
-}
headQName ∷ IR.Exp → Maybe IR.QName
headQName = \case
  IR.Ref _ann (IR.Imported modname name) → Just (IR.QName modname name)
  expr → foreignAccessorQName expr

--------------------------------------------------------------------------------
-- Lowering --------------------------------------------------------------------

{- | Emit the native-loop statements for a recognised run. The first
argument compiles an IR expression (the caller's own recursion, so a
nested loop run lowers through the same match), the second mints a
fresh Lua-side local name from a prefix.
-}
lowerLoop
  ∷ ∀ m
   . Monad m
  ⇒ (IR.Exp → m (Either Lua.Chunk Lua.Exp))
  → (Text → m Name.Name)
  → NativeLoop
  → m Lua.Chunk
lowerLoop compile fresh = \case
  ForeachLoop arr f → do
    (arrPre, arrExp) ← atomize "$xs" arr
    index ← fresh "$i"
    let elemAt = Lua.varIndex arrExp (Lua.varName index)
        for = forNum index (Lua.Integer 1) (Lua.hash arrExp)
    case unaryLambda f of
      Just (param, lambdaBody) → do
        bodyStmts ← runStatements lambdaBody
        let binder = case param of
              IR.ParamNamed _ann x → [Lua.local1 (fromName x) elemAt]
              IR.ParamUnused _ann → []
        pure $ scoped arrPre (for (Lua.ann <$> (binder <> bodyStmts)))
      Nothing → do
        (fPre, fExp) ← atomize "$f" f
        -- f(xs[i])() — apply, then run the returned thunk, exactly the
        -- foreign implementation's step.
        let step =
              runCall (Lua.functionCall (Lua.functionCall fExp [elemAt]) [])
        pure $ scoped (arrPre <> fPre) (for [Lua.ann step])
  ForRangeLoop lo hi f →
    case unaryLambda f of
      Just (param, lambdaBody) → do
        loExp ← compileExp lo
        hiExp ← compileExp hi
        index ← case param of
          IR.ParamNamed _ann x → pure (fromName x)
          IR.ParamUnused _ann → fresh "$i"
        bodyStmts ← runStatements lambdaBody
        pure [forNum index loExp (oneLess hiExp) (Lua.ann <$> bodyStmts)]
      Nothing → do
        -- Pre-binding f forces lo and hi to pre-bind too, keeping the
        -- three evaluations in application order.
        (loPre, loExp) ← atomize "$lo" lo
        (hiPre, hiExp) ← atomize "$hi" hi
        (fPre, fExp) ← atomize "$f" f
        index ← fresh "$i"
        -- f(i)() — apply, then run, as in the foreign implementation.
        let step =
              runCall
                ( Lua.functionCall
                    (Lua.functionCall fExp [Lua.varName index])
                    []
                )
        pure $
          scoped
            (loPre <> hiPre <> fPre)
            (forNum index loExp (oneLess hiExp) [Lua.ann step])
  WhileLoop cond body → do
    (condPre, condExp) ← case cond of
      IR.AbsN _ann (IR.ParamUnused _ :| []) inner →
        compile inner >>= \case
          -- The thunk body is a plain expression: inline it as the
          -- predicate, re-evaluated per iteration exactly as the thunk
          -- call would be.
          Right e → pure ([], e)
          Left _chunk → predicateCall
      _ → predicateCall
    (bodyPre, bodyStmts) ← case body of
      IR.AbsN _ann (IR.ParamUnused _ :| []) _inner →
        ([],) <$> runStatements body
      _ → do
        (pre, bodyFn) ← atomize "$act" body
        pure (pre, [runCall (Lua.functionCall bodyFn [])])
    pure $
      scoped
        (condPre <> bodyPre)
        (Lua.While (Lua.ann condExp) (Lua.ann <$> bodyStmts))
   where
    predicateCall = do
      (pre, condFn) ← atomize "$cond" cond
      pure (pre, Lua.functionCall condFn [])
 where
  compileExp ∷ IR.Exp → m Lua.Exp
  compileExp e = either Lua.chunkToExpression id <$> compile e

  -- A literal one-parameter lambda: the shape whose body inlines as the
  -- loop body.
  unaryLambda ∷ IR.Exp → Maybe (IR.Parameter IR.Ann, IR.Exp)
  unaryLambda = \case
    IR.AbsN _ann (param :| []) lambdaBody → Just (param, lambdaBody)
    _ → Nothing

  {- Run an Effect/ST value for its effect: the statements of a literal
  thunk's body (value discarded), or the thunk call @e()@ — see the
  module haddock for the 'spliceLocalBudget' guard. -}
  runStatements ∷ IR.Exp → m [Lua.Statement]
  runStatements = \case
    IR.AbsN _ann (IR.ParamUnused _ :| []) inner →
      compile inner <&> \case
        Right e → dropValue e
        Left chunk
          | blockLocals chunk <= spliceLocalBudget → statementize chunk
          | otherwise →
              [runCall (Lua.functionCall (Lua.chunkToExpression chunk) [])]
    e →
      compile (IR.App IR.noAnn e (IR.EffectRunArg IR.noAnn)) <&> \case
        Right ex → dropValue ex
        -- A nested recognised loop lowers to statements already.
        Left chunk → chunk

  -- Bind a non-atomic expression to a fresh local so the loop reads it
  -- without re-evaluating; a bare name or scalar literal is used as-is.
  atomize ∷ Text → IR.Exp → m ([Lua.Statement], Lua.Exp)
  atomize prefix e = do
    ex ← compileExp e
    if isAtom ex
      then pure ([], ex)
      else do
        name ← fresh prefix
        pure ([Lua.local1 name ex], Lua.varName name)

  isAtom ∷ Lua.Exp → Bool
  isAtom = \case
    Lua.Nil → True
    Lua.Boolean _ → True
    Lua.Integer _ → True
    Lua.Float _ → True
    Lua.String _ → True
    Lua.Var (Lua.Ann (Lua.VarName _)) → True
    _ → False

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

{- | Scope a run of pre-binding statements to their loop with a
@do … end@ block, so the temporaries do not count against the enclosing
function's active locals past the loop; a loop without pre-bindings
needs no block.
-}
scoped ∷ [Lua.Statement] → Lua.Statement → Lua.Chunk
scoped pre loop
  | null pre = [loop]
  | otherwise = [Lua.Do (Lua.ann <$> (pre <> [loop]))]

-- | A numeric @for@ with unit step over annotation-free bounds.
forNum
  ∷ Name.Name
  → Lua.Exp
  → Lua.Exp
  → [Lua.Annotated Lua.Comments Lua.StatementF]
  → Lua.Statement
forNum index start limit = Lua.ForNum index (Lua.ann start) (Lua.ann limit) Nothing

-- | @e - 1@, folded for a literal bound.
oneLess ∷ Lua.Exp → Lua.Exp
oneLess = \case
  Lua.Integer n → Lua.Integer (n - 1)
  e → Lua.sub e (Lua.Integer 1)

-- | A call in statement position: run for its effect.
runCall ∷ Lua.Exp → Lua.Statement
runCall = Lua.CallStatement . Lua.ann

{- | Rewrite a function-body chunk that runs for a /value/ into the
statements that run it for its /effect/: tail 'Lua.Return's — including
those on the branch tails of a trailing 'Lua.IfThenElse' or 'Lua.Do' —
become evaluation statements with the value discarded. Statements
before the tail are unchanged; nested function literals are separate
activations and are not entered. Code-generated nodes carry no
comments, so none are moved.
-}
statementize ∷ Lua.Chunk → Lua.Chunk
statementize chunk = Lua.unAnn <$> statementizeAnn (Lua.ann <$> chunk)

statementizeAnn
  ∷ [Lua.Annotated Lua.Comments Lua.StatementF]
  → [Lua.Annotated Lua.Comments Lua.StatementF]
statementizeAnn block = case reverse block of
  [] → []
  (comments, lastStatement) : reversedLeading →
    reverse reversedLeading <> case lastStatement of
      Lua.Return es → Lua.ann <$> foldMap (dropValue . Lua.unAnn) es
      Lua.IfThenElse c thenB elseB →
        [
          ( comments
          , Lua.IfThenElse c (statementizeAnn thenB) (statementizeAnn elseB)
          )
        ]
      Lua.Do b → [(comments, Lua.Do (statementizeAnn b))]
      _ → [(comments, lastStatement)]

{- | Evaluate an expression in statement position, discarding its value:
a call becomes a call statement, an effect-free atom disappears, and
anything else is bound to the throwaway @_@ local so its evaluation
(and any error it raises) is preserved.
-}
dropValue ∷ Lua.Exp → [Lua.Statement]
dropValue = \case
  e@Lua.FunctionCall {} → [runCall e]
  e@Lua.MethodCall {} → [runCall e]
  Lua.Paren (Lua.Ann inner) → dropValue inner
  Lua.Nil → []
  Lua.Boolean _ → []
  Lua.Integer _ → []
  Lua.Float _ → []
  Lua.String _ → []
  Lua.Function {} → []
  Lua.Var (Lua.Ann (Lua.VarName _)) → []
  e → [Lua.local1 discardLocal e]

{- | The throwaway binder for a discarded non-call value; Lua allows the
redeclaration when several occur in one block.
-}
discardLocal ∷ Name.Name
discardLocal = Name.unsafeName "_"

{- | Block-level local slots a chunk would occupy in its enclosing
activation, the budget 'runStatements' checks before splicing: the
counting twin of
'Language.PureScript.Backend.Lua.Optimizer.activationLocalSlots', kept
local because the optimizer builds on this module's output, not the
other way around.
-}
blockLocals ∷ Lua.Chunk → Int
blockLocals = sum . fmap slots
 where
  slots ∷ Lua.Statement → Int
  slots = \case
    Lua.Local names _values → length names
    Lua.LocalFunction {} → 1
    Lua.ForNum _name _start _limit _step body → 1 + annotatedLocals body
    Lua.ForIn names _exprs body → length names + annotatedLocals body
    Lua.IfThenElse _predicate thenB elseB →
      annotatedLocals thenB + annotatedLocals elseB
    Lua.Do body → annotatedLocals body
    Lua.While _predicate body → annotatedLocals body
    Lua.Repeat body _predicate → annotatedLocals body
    Lua.Assign {} → 0
    Lua.Return {} → 0
    Lua.CallStatement {} → 0
    Lua.Break → 0
  annotatedLocals = sum . fmap (slots . Lua.unAnn)

{- | The largest thunk body spliced inline as a loop body. A magic-do
chunk holds up to ~150 locals
('Language.PureScript.Backend.IR.MagicDo.chunkSize') and Lua caps
active locals per function at 200 (@LUAI_MAXVARS@), so the enclosing
function can absorb a bounded splice only.
-}
spliceLocalBudget ∷ Int
spliceLocalBudget = 40

fromName ∷ IR.Name → Name.Name
fromName = Name.makeSafe . IR.nameToText
