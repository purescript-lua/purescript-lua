module Language.PureScript.Backend.Lua.Optimizer where

import Control.Monad.Trans.Accum (Accum, add, execAccum)
import Data.Map qualified as Map
import Language.PureScript.Backend.Lua.Fixture qualified as Fixture
import Language.PureScript.Backend.Lua.Limits (LuaLimits)
import Language.PureScript.Backend.Lua.Localize (localizeChunk)
import Language.PureScript.Backend.Lua.Name qualified as Lua
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
  , Statement
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  , pattern Ann
  )
import Language.PureScript.Backend.Lua.Types qualified as Lua

{- | Localization runs after the rewrite rules: projection folds can
eliminate module-table reads, and the reads that remain are the ones
worth counting and caching.
-}
optimizeChunk ∷ LuaLimits → Chunk → Chunk
optimizeChunk limits =
  localizeChunk limits Fixture.moduleName . fmap optimizeStatement

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

optimizeStatement ∷ Statement → Statement
optimizeStatement = everywhereStat identity optimizeExpression

optimizeExpression ∷ Exp → Exp
optimizeExpression = foldr (>>>) identity rewriteRulesInOrder

rewriteRulesInOrder ∷ [RewriteRule]
rewriteRulesInOrder =
  [ reduceTableDefinitionAccessor
  , foldFieldProjectionThroughScopeCall
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
the call. See issue #159.

The rule declines when a leading statement contains a body-level 'Return':
such an early return exits the call on a path the projection would not
cover. A 'Return' inside a nested 'Function' (or 'LocalFunction') belongs
to a different activation and does not count, while a 'Return' inside a
loop or 'Do' block at body level does.
-}
foldFieldProjectionThroughScopeCall ∷ RewriteRule
foldFieldProjectionThroughScopeCall original
  | Just (accessedField, leading, returnExp) ←
      matchScopeCallProjection original =
      let projectedReturnValue =
            optimizeExpression (Lua.varField returnExp accessedField)
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
    -- A nested (local) function is a different activation: its returns do
    -- not exit this call.
    LocalFunction {} → False
    Assign {} → False
    Local {} → False
    CallStatement {} → False
    Break → False

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
