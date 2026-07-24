module Language.PureScript.Backend.Lua.Optimizer where

import Control.Monad.Trans.Accum (Accum, add, execAccum)
import Data.Map qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.Lua.Fixture qualified as Fixture
import Language.PureScript.Backend.Lua.Limits (LuaLimits, workingLocalCeiling)
import Language.PureScript.Backend.Lua.Linker.Foreign (chunkScopeUsesVararg)
import Language.PureScript.Backend.Lua.Localize (localizeChunk, namesInBlock)
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Promote (promoteChunk)
import Language.PureScript.Backend.Lua.Traversal
  ( everywhereExp
  , everywhereInChunkM
  , everywhereStat
  , everywhereStatM
  )
import Language.PureScript.Backend.Lua.Types
  ( Annotated
  , Chunk
  , Comments
  , Exp
  , ExpF (..)
  , ParamF (..)
  , Statement
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  , pattern Ann
  )
import Language.PureScript.Backend.Lua.Types qualified as Lua

{- | The storage passes run after the rewrite rules: projection folds
can eliminate module-table reads, and the reads that remain are the
ones worth counting. Promotion (stage 2) precedes localization
(stage 1): whatever stays in the module table after promotion — the
unpromoted tail plus demoted references — is exactly what per-function
caching still speeds up.
-}
optimizeChunk ∷ LuaLimits → Chunk → Chunk
optimizeChunk limits =
  localizeChunk limits Fixture.moduleName
    . promoteChunk limits Fixture.moduleName
    . fmap (optimizeStatement limits)

substituteVarForValue ∷ Lua.Name → Exp → Chunk → Chunk
substituteVarForValue name inlinee =
  runIdentity . everywhereInChunkM (pure . subst) pure
 where
  subst = \case
    Lua.Var (Lua.unAnn → Lua.VarName varName) | varName == name → inlinee
    expr → expr

countRefs ∷ Statement → Map Lua.Name (Sum Natural)
countRefs = everywhereStatM pure countRefsInExpression >>> (`execAccum` mempty)
 where
  countRefsInExpression ∷ Exp → Accum (Map Lua.Name (Sum Natural)) Exp
  countRefsInExpression = \case
    expr@(Lua.Var (Lua.unAnn → Lua.VarName name)) →
      add (Map.singleton name (Sum 1)) $> expr
    expr → pure expr

optimizeStatement ∷ LuaLimits → Statement → Statement
optimizeStatement limits =
  everywhereStat identity (optimizeExpression limits)

optimizeExpression ∷ LuaLimits → Exp → Exp
optimizeExpression limits = foldr (>>>) identity (rewriteRulesInOrder limits)

rewriteRulesInOrder ∷ LuaLimits → [RewriteRule]
rewriteRulesInOrder limits =
  [ reduceTableDefinitionAccessor
  , foldFieldProjectionThroughScopeCall limits
  , foldCallThroughScopeCall limits
  , collapseTailLiteralApplication limits
  , foldNotEqual
  ]

type RewriteRule = Exp → Exp

rewriteExpWithRule ∷ RewriteRule → Exp → Exp
rewriteExpWithRule rule = everywhereExp rule identity

--------------------------------------------------------------------------------
-- Rewrite rules for expressions -----------------------------------------------

{- | Rewrites '{ foo = 1, bar = 2 }.foo' to '1'.

IR-visible record literals are already folded by the IR optimizer
('Language.PureScript.Backend.IR.Optimizer.reduceObjectProp'); this rule
catches the constructors that only materialize during lowering. The live
trigger is a projection out of a foreign module — @ObjectProp
(ForeignImport …)@ lowers to a field access into the table of the foreign
source's exports.

Only fires when the constructor is unambiguous: every row is a name-value
row and no field name repeats. A 'TableRowKV' row could carry a string key
equal to the accessed field (e.g. @["foo"] = …@) that this name-keyed lookup
cannot see, and on a repeated name Lua's constructor keeps the last
assignment while a first-match lookup returns the earliest; in either case
the fold could pick the wrong value, so the rule declines. See issue #140.
-}
reduceTableDefinitionAccessor ∷ RewriteRule
reduceTableDefinitionAccessor = \case
  original@(Var (Ann (VarField (Ann (TableCtor rows)) accessedField)))
    | all isNameValue rows
    , not (hasDuplicateNames rows) →
        fromMaybe Nil $
          listToMaybe
            [ fieldValue
            | (_ann, TableRowNV tableField (Ann fieldValue)) ← rows
            , tableField == accessedField
            ]
    | otherwise → original
  e → e
 where
  isNameValue ∷ Annotated Comments TableRowF → Bool
  isNameValue (_ann, row) = case row of
    TableRowNV {} → True
    TableRowKV {} → False
    TableRowV {} → False
  hasDuplicateNames ∷ [Annotated Comments TableRowF] → Bool
  hasDuplicateNames rows =
    let names = [n | (_ann, TableRowNV n _) ← rows]
     in length names /= length (ordNub names)

{- | Rewrites @(function() …; return e end)().foo@ to
@(function() …; return e.foo end)()@.

A no-argument, immediately-invoked function whose last statement is a
@return@ is projected into right after the call. Projecting the field
before returning versus after the call returns is the same value, and no
side effect crosses the call boundary since both happen within the same
activation. The new @e.foo@ projection is immediately re-optimized (rather
than waiting for a later pass) so that, e.g., 'reduceTableDefinitionAccessor'
sees through to a table constructor that would otherwise be hidden behind
the call; the 'LuaLimits' are only forwarded to that re-optimization.
See issue #159.

The rule declines when a leading statement contains a body-level 'Return':
such an early return exits the call on a path the projection would not
cover. A 'Return' inside a nested 'Function' (or 'LocalFunction') belongs
to a different activation and does not count, while a 'Return' inside a
loop or 'Do' block at body level does.
-}
foldFieldProjectionThroughScopeCall ∷ LuaLimits → RewriteRule
foldFieldProjectionThroughScopeCall limits original
  | Just (accessedField, leading, returnExp) ←
      matchScopeCallProjection original =
      let projectedReturnValue =
            optimizeExpression limits (Lua.varField returnExp accessedField)
          returnStatement = Lua.ann (Return [Lua.ann projectedReturnValue])
       in FunctionCall (Lua.ann (Function [] (leading <> [returnStatement]))) []
  | otherwise = original
 where
  -- Matches 'Var (VarField (FunctionCall (Function [] body) []) field)' where
  -- the last statement of 'body' is a single-valued 'Return', splitting it
  -- into the accessed field name, the leading statements, and the returned
  -- expression.
  matchScopeCallProjection
    ∷ Exp → Maybe (Lua.Name, [Annotated Comments StatementF], Exp)
  matchScopeCallProjection = \case
    Var
      ( Ann
          ( VarField
              (Ann (FunctionCall (Ann (Function [] body)) []))
              accessedField
            )
        ) → case reverse body of
        Ann (Return [Ann returnExp]) : reverseLeading
          | not (any containsReturn reverseLeading) →
              Just (accessedField, reverse reverseLeading, returnExp)
        _ → Nothing
    _ → Nothing

{- | Whether a statement contains a 'Return' at the level of the enclosing
function body — one that exits the activation. A 'Return' inside a nested
'Function' (or 'LocalFunction') belongs to a different activation and does
not count, while a 'Return' inside a loop or 'Do' block at body level does.
-}
containsReturn ∷ Annotated Comments StatementF → Bool
containsReturn (Ann statement) = case statement of
  Return {} → True
  IfThenElse _predicate thenBlock elseBlock →
    any containsReturn thenBlock || any containsReturn elseBlock
  Do body → any containsReturn body
  While _predicate body → any containsReturn body
  Repeat body _predicate → any containsReturn body
  ForNum _name _start _limit _step body → any containsReturn body
  ForIn _names _exprs body → any containsReturn body
  LocalFunction {} → False
  Assign {} → False
  Local {} → False
  CallStatement {} → False
  Break → False

{- | Rewrites @(function() …; return e end)()(args)@ to
@(function() …; return e(args) end)()@: a call applied to the result of a
no-argument, immediately-invoked function is folded into its @return@s.
The shape is how the code generator runs a selected thunk — "pick an
effect, then run it" lowers to a scope call immediately applied — and
folding the application inward exposes a plain scope call that
'collapseTailLiteralApplication' can then splice away. The freshly built
call is folded once more by this same rule, in case the returned
expression is itself an applied scope call. The rebuilt literal is then
handed to 'collapseTailLiteralApplication' directly: the pushed
application may have landed on a returned function literal — a
beta-redex at a depth the bottom-up driver has already passed — and
while a literal in a function tail re-collapses when the driver reaches
that enclosing function, one in expression position (a table row, an
operand) has no later chance. The 'LuaLimits' are only forwarded to that
collapse.

Applying before versus after the call returns is observably the same: the
leading statements run first either way, the returned expression is
evaluated before the arguments in both forms, and @return e(args)@ is a
tail call, so even the activation depth at the moment the result runs is
unchanged.

The tail chain the fold covers is a single-valued 'Return', or an
'IfThenElse'/'Do' whose every branch ends in one, recursively — the thunk
selection is exactly a branching tail. The rule declines when:

* a leading statement (of the body or of any branch on the tail chain)
  'containsReturn': such an early return leaves the call on a path the
  fold does not cover;

* the tail chain has a fall-off path (a branch not ending in a 'Return',
  an empty body): falling off yields @nil@, which the original code then
  calls — an error the folded code would not reproduce;

* the tail 'Return' is not single-valued: the call consumes the first
  value only after Lua's adjustment, but the fold cannot drop the other
  results without dropping their effects;

* the arguments mention @...@ in their own scope: moved inside the
  no-parameter callee, it would be rebound or fail to load;

* a free name of the arguments collides with a local the callee's body
  declares ('declaredNamesInActivation'): moved inside, the argument
  would resolve the name to the callee's local instead of the enclosing
  scope's binding;

* the tail chain branches and any argument is not a name or a literal:
  the arguments are duplicated into every return site — evaluated at most
  once, since a single branch runs, but syntactically repeated — and
  atoms keep that duplication trivial.
-}
foldCallThroughScopeCall ∷ LuaLimits → RewriteRule
foldCallThroughScopeCall limits = \case
  original@( FunctionCall
               (Ann (FunctionCall (Ann (Function [] body)) []))
               args
             )
      | not (chunkScopeUsesVararg argsBlock)
      , Set.disjoint (declaredNamesInActivation body) (namesInBlock argsBlock)
      , Just body' ← pushCallIntoTail body →
          let folded =
                collapseTailLiteralApplication limits (Function [] body')
           in FunctionCall (Lua.ann folded) []
      | otherwise → original
     where
      argsBlock = [Lua.ann (Return args)]

      atomicArgs ∷ Bool
      atomicArgs = all (isAtom . Lua.unAnn) args
       where
        isAtom ∷ Exp → Bool
        isAtom = \case
          Nil → True
          Boolean _ → True
          Integer _ → True
          Float _ → True
          String _ → True
          Var (Ann (VarName _)) → True
          _ → False

      pushCallIntoTail
        ∷ [Annotated Comments StatementF]
        → Maybe [Annotated Comments StatementF]
      pushCallIntoTail block = case reverse block of
        lastStatement : reverseLeading
          | not (any containsReturn reverseLeading) →
              pushIntoStatement lastStatement <&> \pushed →
                reverse reverseLeading <> [pushed]
        _ → Nothing

      pushIntoStatement
        ∷ Annotated Comments StatementF
        → Maybe (Annotated Comments StatementF)
      pushIntoStatement (c, statement) =
        (c,) <$> case statement of
          Return [returnedValue] →
            Just . Return . pure . Lua.ann $
              foldCallThroughScopeCall limits (FunctionCall returnedValue args)
          IfThenElse p thenBlock elseBlock
            | atomicArgs →
                IfThenElse p
                  <$> pushCallIntoTail thenBlock
                  <*> pushCallIntoTail elseBlock
          Do doBody → Do <$> pushCallIntoTail doBody
          _ → Nothing
  e → e

{- | Every name declared at the activation level of a block: block-level
declarations at any depth count, while nested function literals are
separate scopes whose declarations are invisible outside. The name-set
counterpart of 'activationLocalSlots'.
-}
declaredNamesInActivation ∷ [Annotated Comments StatementF] → Set Lua.Name
declaredNamesInActivation = foldMap (declared . Lua.unAnn)
 where
  declared ∷ StatementF Comments → Set Lua.Name
  declared = \case
    Local names _values → Set.fromList (toList names)
    LocalFunction fname _params _body → Set.singleton fname
    ForNum n _start _limit _step body →
      Set.insert n (declaredNamesInActivation body)
    ForIn names _exprs body →
      Set.fromList (toList names) <> declaredNamesInActivation body
    IfThenElse _predicate thenBlock elseBlock →
      declaredNamesInActivation thenBlock
        <> declaredNamesInActivation elseBlock
    Do body → declaredNamesInActivation body
    While _predicate body → declaredNamesInActivation body
    Repeat body _predicate → declaredNamesInActivation body
    Assign {} → mempty
    Return {} → mempty
    CallStatement {} → mempty
    Break → mempty

{- | Rewrites @function(…) …; return (function(p1, …) <stmts> end)(a1, …)
end@ to @function(…) …; local p1, … = a1, …; <stmts> end@: an
immediately-applied function literal in tail position is spliced into the
enclosing function body, its parameters bound as locals (no binding
statement when the literal is nullary). The nullary shape is what
magic-do's chunked statement sequences lower to inside an n-ary function
literal (issue #230); the parameterized shape is the beta-redex
'foldCallThroughScopeCall' leaves behind when the tail it pushed the
application into returned a literal (issue #295). Either way the cost is
one closure allocation and one extra call on every invocation.

Tail position is what makes the splice safe. The parent's @return call@
forwarded /all/ of the call's results (an explicit 'Paren' would adjust
them to one and correctly fails the match), so after the splice the inner
@return@s — or falling off the end, for an empty result — produce the
same values directly. Early @return@s among the leading statements exit
the parent on their own paths before the splice point either way, so
unlike 'foldFieldProjectionThroughScopeCall' this rule does not need to
decline on them. And because the splice point is the parent's last
statement, no parent code follows it: Lua's local scoping is positional,
so the spliced statements see exactly the environment the called
function closed over, and the locals they declare — including
re-declarations of a name the parent already binds, which are legal and
shadow only from that point on — cannot capture any later read.

The one-statement @local@ is the exact translation of Lua's call binding:
the whole initializer list is evaluated before any name binds (so an
argument reading an outer @x@ can never see a parameter named @x@), a
multi-valued expression last in the list expands, missing values fill
with @nil@, and extra values are evaluated, then discarded — the same
adjustment rules the call performed. And the arguments do not move across
a scope boundary: the call site already was the parent's last statement,
so they are evaluated in the same environment at the same program point
in both forms — which is also why @...@ among the arguments needs no
check, unlike in 'foldCallThroughScopeCall'.

Conditions checked:

* Every parameter of the called literal is a 'ParamNamed', no name
  repeating: a 'ParamVararg' cannot be bound by a @local@, a
  'ParamUnused' has no name to bind, and while @local x, x = …@ does
  reproduce a duplicate-parameter call — both bind the last occurrence —
  declining removes the need to reason about it. IR-derived literals
  always name their parameters distinctly, so declining costs nothing.

* A nullary literal applied to arguments declines: no @local@ binds zero
  names, and dropping the arguments would drop their effects.

* The spliced statements must not mention @...@ in their own scope
  ('chunkScopeUsesVararg'): a parameterless function cannot legally do
  so, but on such (only ever hand-written) input the splice would rebind
  @...@ to the parent's varargs instead of failing to load.

* A local budget: the splice undoes exactly the chunking with which
  magic-do keeps any single function's locals bounded (issue #19), so the
  merged body — parameter binding included — must fit the same
  'workingLocalCeiling' the storage passes budget against: parameters
  plus 'activationLocalSlots'. One magic-do chunk
  ('Language.PureScript.Backend.IR.MagicDo.chunkSize' statements) fits a
  typical parent, while two adjacent chunks exceed the ceiling and keep
  their boundary. The passes running later stay sound either way:
  'localizeChunk' budgets its cache locals against what is actually
  declared after the splice, and only gains upvalue headroom from the
  disappearing proto.

The rule re-applies itself to the merged function: the new tail may again
be an applied-literal return — 'foldCallThroughScopeCall' builds such
tails at depths the bottom-up driver has already passed — and every round
re-checks the conditions above.
-}
collapseTailLiteralApplication ∷ LuaLimits → RewriteRule
collapseTailLiteralApplication limits = \case
  Function params body
    | Just (leading, binding, spliced) ← matchTailLiteralApplication body
    , not (chunkScopeUsesVararg spliced)
    , let merged = leading <> binding <> spliced
    , length params + activationLocalSlots merged
        <= workingLocalCeiling limits →
        -- The merged tail may itself be an applied-literal return — one
        -- 'foldCallThroughScopeCall' built after the bottom-up driver had
        -- already passed that depth — so keep collapsing while the budget
        -- admits it; every round consumes one nesting level.
        collapseTailLiteralApplication limits (Function params merged)
  e → e
 where
  -- Splits a function body whose last statement is a single-valued
  -- 'Return' of an immediately-applied function literal into the leading
  -- statements, the parameter binding (one simultaneous 'Local', or
  -- nothing for a nullary literal), and the statements to splice.
  matchTailLiteralApplication
    ∷ [Annotated Comments StatementF]
    → Maybe
        ( [Annotated Comments StatementF]
        , [Annotated Comments StatementF]
        , [Annotated Comments StatementF]
        )
  matchTailLiteralApplication body = case reverse body of
    Ann (Return [Ann (FunctionCall (Ann (Function params spliced)) args)])
      : reverseLeading → do
        names ← traverse namedParam params
        binding ← case nonEmpty names of
          Nothing → [] <$ guard (null args)
          Just paramNames → do
            guard (length names == length (ordNub names))
            Just [Lua.ann (Local paramNames args)]
        pure (reverse reverseLeading, binding, spliced)
    _ → Nothing

  namedParam ∷ Annotated Comments ParamF → Maybe Lua.Name
  namedParam (Ann param) = case param of
    ParamNamed paramName → Just paramName
    ParamUnused → Nothing
    ParamVararg → Nothing

{- | Over-approximates the local-variable slots a block occupies in the
activation of its enclosing function: declarations at every block depth
count, while nested function literals are separate protos with their own
register space and are not entered. The over-approximation — sibling
blocks release their slots at runtime but are counted cumulatively — is
safe for budgeting: it can only decline a rewrite, never admit one over
the limit.
-}
activationLocalSlots ∷ [Annotated Comments StatementF] → Int
activationLocalSlots = sum . fmap (slots . Lua.unAnn)
 where
  slots ∷ StatementF Comments → Int
  slots = \case
    Local names _values → length names
    LocalFunction {} → 1
    ForNum _name _start _limit _step body → 1 + activationLocalSlots body
    ForIn names _exprs body → length names + activationLocalSlots body
    IfThenElse _predicate thenBlock elseBlock →
      activationLocalSlots thenBlock + activationLocalSlots elseBlock
    Do body → activationLocalSlots body
    While _predicate body → activationLocalSlots body
    Repeat body _predicate → activationLocalSlots body
    Assign {} → 0
    Return {} → 0
    CallStatement {} → 0
    Break → 0

{- | Rewrites @not (a == b)@ to @a ~= b@ and @not (a ~= b)@ to @a == b@.
Lua's @~=@ is exactly the negation of @==@, so the rewrite is
unconditional. The IR emits the @not (==)@ shape when it lowers a
'Language.PureScript.Backend.IR.Types.PrimNot' over an 'Eq' — from the
boolean-if simplification of a comparison (issue #178) or a lifted @/=@ —
and this peephole restores the operator luacheck expects.
-}
foldNotEqual ∷ RewriteRule
foldNotEqual = \case
  UnOp Lua.LogicalNot (Ann (BinOp Lua.EqualTo a b)) → BinOp Lua.NotEqualTo a b
  UnOp Lua.LogicalNot (Ann (BinOp Lua.NotEqualTo a b)) → BinOp Lua.EqualTo a b
  e → e
