module Language.PureScript.Backend.Lua.Optimizer where

import Control.Monad.Trans.Accum (Accum, add, execAccum)
import Data.Map qualified as Map
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
  , Exp
  , ExpF (..)
  , Statement
  , TableRowF (..)
  , VarF (..)
  , pattern Ann
  )
import Language.PureScript.Backend.Lua.Types qualified as Lua

optimizeChunk ∷ Chunk → Chunk
optimizeChunk = fmap optimizeStatement

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
  ]

type RewriteRule = Exp → Exp

rewriteExpWithRule ∷ RewriteRule → Exp → Exp
rewriteExpWithRule rule = everywhereExp rule identity

--------------------------------------------------------------------------------
-- Rewrite rules for expressions -----------------------------------------------

{- | Rewrites '{ foo = 1, bar = 2 }.foo' to '1'.

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
  isNameValue ∷ Annotated () TableRowF → Bool
  isNameValue (_ann, row) = case row of
    TableRowNV {} → True
    TableRowKV {} → False
  hasDuplicateNames ∷ [Annotated () TableRowF] → Bool
  hasDuplicateNames rows =
    let names = [n | (_ann, TableRowNV n _) ← rows]
     in length names /= length (ordNub names)
