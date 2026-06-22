{- | Post-codegen safety net for Lua 5.1's parser-nesting cap.

Lua's parser bounds how deeply expressions and statements may nest
(@LUAI_MAXCCALLS@, ~200 C-stack frames): a chunk that nests too deeply fails to
/load/ — before any code runs — with @chunk has too many syntax levels@. This is
unique to the Lua target (issue #104). The
'Language.PureScript.Backend.IR.FlattenDeepBinds' pass flattens the common cause
(deep @do@\/@>>=@ chains), but it can bail (a too-large live set at every cut),
and other constructs (@case@ trees, string concatenation, wide literals) are not
yet flattened at all. Either way the result would be silently-unloadable Lua.

'exceedsNestingLimit' measures the chunk's maximum syntactic nesting depth and
flags it when it crosses a conservative threshold ('nestingLimit', below
@LUAI_MAXCCALLS@). The caller turns that into a clear compiler error instead of
emitting a chunk that no Lua interpreter can load.

== The metric

'maxChunkDepth' mirrors the recursive-descent parser's call depth rather than
the raw AST height: it adds a level for a function /body/, a function-call
/argument/, an operator operand, a table value, and an index\/field access — the
positions the parser recurses into — but /not/ for the left spine of a curried
call @f(a)(b)@, which the parser consumes iteratively. So it tracks the real
limit closely while staying well above what flattened output produces.
-}
module Language.PureScript.Backend.Lua.NestingCheck
  ( exceedsNestingLimit
  , maxChunkDepth
  , nestingLimit
  ) where

import Language.PureScript.Backend.Lua.Types
  ( Chunk
  , ExpF (..)
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  , unAnn
  )

{- | Conservative nesting-depth threshold, below Lua 5.1's @LUAI_MAXCCALLS@
(~200). A chunk measuring beyond this is rejected rather than emitted as
unloadable Lua. Flattened output ('FlattenDeepBinds') measures far below it.
-}
nestingLimit ∷ Int
nestingLimit = 180

{- | @Just depth@ when the chunk's nesting exceeds 'nestingLimit',
else @Nothing@.
-}
exceedsNestingLimit ∷ Chunk → Maybe Int
exceedsNestingLimit = guarded (> nestingLimit) . maxChunkDepth

-- | Maximum syntactic nesting depth of a chunk (see the metric note above).
maxChunkDepth ∷ Chunk → Int
maxChunkDepth = blockDepth

blockDepth ∷ [StatementF a] → Int
blockDepth = foldl' (\acc s → acc `max` statementDepth s) 0

statementDepth ∷ StatementF a → Int
statementDepth = \case
  Assign v e → varDepth (unAnn v) `max` expDepth (unAnn e)
  Local _name me → maybe 0 (expDepth . unAnn) me
  Return e → expDepth (unAnn e)
  ForeignSourceStat _ → 0
  IfThenElse c t e →
    1
      + expDepth (unAnn c)
        `max` blockDepth (unAnn <$> t)
        `max` blockDepth (unAnn <$> e)

expDepth ∷ ExpF a → Int
expDepth = \case
  Nil → 0
  Boolean _ → 0
  Integer _ → 0
  Float _ → 0
  String _ → 0
  ForeignSourceExp _ → 0
  Var v → varDepth (unAnn v)
  UnOp _op e → 1 + expDepth (unAnn e)
  BinOp _op l r → 1 + expDepth (unAnn l) `max` expDepth (unAnn r)
  Function _params body → 1 + blockDepth (unAnn <$> body)
  TableCtor rows → 1 + foldl' (\acc r → acc `max` rowDepth (unAnn r)) 0 rows
  -- The callee spine of @f(a)(b)@ is parsed iteratively, so it does not add a
  -- level; each argument position does.
  FunctionCall f args →
    expDepth (unAnn f)
      `max` (1 + foldl' (\acc a → acc `max` expDepth (unAnn a)) 0 args)

varDepth ∷ VarF a → Int
varDepth = \case
  VarName _ → 0
  VarIndex e1 e2 → 1 + expDepth (unAnn e1) `max` expDepth (unAnn e2)
  VarField e _ → 1 + expDepth (unAnn e)

rowDepth ∷ TableRowF a → Int
rowDepth = \case
  TableRowKV k v → expDepth (unAnn k) `max` expDepth (unAnn v)
  TableRowNV _name v → expDepth (unAnn v)
