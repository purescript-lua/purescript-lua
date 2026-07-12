{- | Per-function caching of module-table fields (issue #174, stage 1).

Every top-level binding lives in the module-scope table @M@
('Language.PureScript.Backend.Lua.Fixture.moduleName'), so every
inter-binding reference is a hash lookup on every evaluation. Reading a
local is measurably faster under PUC Lua, and in a LuaJIT trace a local
is a register where a table field is a guarded load — localizing
module-table reads is the classic optimization LuaJIT performance
guides recommend for hot Lua.

This pass rewrites module-table field reads used repeatedly within a
function into reads of a local cached once at function entry:

> M.Data_Array_span = function(p, arr)
>   local Data_Array_index = M.Data_Array_index
>   while true do
>     local v = Data_Array_index(arr)(i)
>     …

== Which reads are cached

Only reads that execute within the activation of the function being
rewritten: reads directly in its body, including the bodies of
zero-argument immediately-invoked function literals
(@(function() … end)()@, the code generator's expression-position scope
wrapper), which run synchronously within the enclosing activation and
are looked through transparently — mirroring their treatment in
"Language.PureScript.Backend.Lua.Loopify". Reads inside any other
nested function literal are left to that function's own rewrite: moving
a read out of a closure into the enclosing function would change /when/
it executes relative to module initialization, and the laziness
analysis ("Language.PureScript.CoreFn.Laziness") may have proved a
recursive group safe precisely because that reference is delayed under
a lambda.

A field qualifies when its reads are worth one up-front table read per
activation. Occurrences are weighted by execution certainty ('Ctx'):
a read inside a loop (a @while@\/@repeat@\/@for@ body, or a
@while@\/@repeat@ condition — re-evaluated every iteration) weighs 2,
a read on the unconditional spine of the body weighs 1, and a read
inside a conditional branch (an @if@ arm, the right operand of
@and@\/@or@) weighs 0; fields with total weight ≥ 2 are cached. So a
single loop read qualifies (hoisted, it is read once per call instead
of once per iteration, and inside a LuaJIT loop trace it becomes a
loop-invariant register), two unconditional reads qualify, but a
single straight-line read (a wash) or a pair of branch-only reads (a
tax on every activation that takes the other branch — the naive-fib
shape) do not. Once a field qualifies, all its region occurrences are
rewritten, conditional ones included: the cache local exists by then,
so those rewrites are pure wins.

== Semantics

Within a single activation the module table is frozen: its fields are
assigned only by statements outside any function body (the module-init
sequence), and no such statement can run while a generated function's
activation is in progress. Hoisting a field read from any point of an
activation to its entry therefore yields the same value. The pass
checks this precondition over the whole chunk rather than assuming it:
unless every occurrence of the module-table name inside a function body
is a plain field read — no field writes, no bare references that could
alias or mutate the table, no shadowing declarations of the name (all
shapes only hand-written FFI could contain) — the chunk is left
completely unchanged. Beyond what the scan can see locally, the pass
assumes module init does not suspend a generated activation mid-body
and resume it after further init statements (no coroutine yields out of
module init — PureScript top-level bindings are pure values, so
generated init code has no effects to suspend).

== Budgets

The rewrite must not push generated code toward the target's
per-function limits that motivated the module table in the first place
(issue #19). The hard limits come in as
'Language.PureScript.Backend.Lua.Limits.LuaLimits' (Lua 5.1: 60
upvalues, 200 locals):

* /Upvalues./ A cache local is referenced only from the caching
  function's own activation region, never from nested (non-IIFE)
  function literals, so no new upvalue chains arise. The exception is
  the looked-through IIFEs, which are function protos underneath:
  cache names referenced inside them occupy upvalue slots. The pass
  bounds the sum of a region IIFE's referenced names and the planned
  cache count by 'workingUpvalueCeiling' (an over-approximation of the
  proto's upvalue demand — it also counts the IIFE's own locals and
  globals, which cost no slots — so it can only under-cache).

* /Locals./ Cache locals are capped at
  'maxCachedFieldsPerFunction' per function, prioritized by use count,
  and further limited so that parameters, declared locals, and caches
  stay under 'workingLocalCeiling'.

Every budget overflow degrades the specific function back to plain
@M.field@ reads — the worst case is exactly the input chunk.
-}
module Language.PureScript.Backend.Lua.Localize
  ( localizeChunk
  , maxCachedFieldsPerFunction

    -- * Shared with "Language.PureScript.Backend.Lua.Promote"
  , moduleTableStable
  , namesInBlock
  ) where

import Data.Map.Strict qualified as Map
import Data.Semigroup (Max (..))
import Data.Set qualified as Set
import Language.PureScript.Backend.Lua.Limits
  ( LuaLimits
  , workingLocalCeiling
  , workingUpvalueCeiling
  )
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Types
  ( Annotated
  , BinaryOp (..)
  , Chunk
  , Comments
  , Exp
  , ExpF (..)
  , ParamF (..)
  , Statement
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  , ann
  , unAnn
  , varField
  , varName
  , pattern Ann
  )
import Prelude hiding (local)

type Block = [Annotated Comments StatementF]

-- | Cap on cache locals introduced per function.
maxCachedFieldsPerFunction ∷ Int
maxCachedFieldsPerFunction = 30

{- | Cache repeated module-table field reads in function-entry locals,
budgeting against the given target limits. The 'Name' argument is the
module-table name ('Language.PureScript.Backend.Lua.Fixture.moduleName').
Returns the chunk unchanged when the stability precondition does not
hold — see the module documentation.
-}
localizeChunk ∷ LuaLimits → Name → Chunk → Chunk
localizeChunk limits m chunk
  | moduleTableStable m chunk = walkStatement limits m TopLevel <$> chunk
  | otherwise = chunk

--------------------------------------------------------------------------------
-- Rewriting walk --------------------------------------------------------------

{- | Where the walk currently is. Outside any function ('TopLevel') no
read is rewritten and every function literal — an IIFE callee included,
since there is no enclosing activation to hoist into — starts its own
caching region. Inside a function ('Region') the selected reads are
rewritten and IIFEs are walked transparently as part of the region.
-}
data WalkMode
  = TopLevel
  | -- | selected field → its cache local
    Region (Map Name Name)

walkBlock ∷ LuaLimits → Name → WalkMode → Block → Block
walkBlock limits m mode = fmap (fmap (walkStatement limits m mode))

walkStatement ∷ LuaLimits → Name → WalkMode → Statement → Statement
walkStatement limits m mode = \case
  Assign vars vals → Assign (goVar <$> vars) (goAnn <$> vals)
  Local names vals → Local names (goAnn <$> vals)
  IfThenElse p tb eb → IfThenElse (goAnn p) (goBlock tb) (goBlock eb)
  Return es → Return (goAnn <$> es)
  CallStatement e → CallStatement (goAnn e)
  Do body → Do (goBlock body)
  While p body → While (goAnn p) (goBlock body)
  Repeat body p → Repeat (goBlock body) (goAnn p)
  ForNum n start limit step body →
    ForNum n (goAnn start) (goAnn limit) (goAnn <$> step) (goBlock body)
  ForIn names es body → ForIn names (goAnn <$> es) (goBlock body)
  LocalFunction n params body →
    LocalFunction n params (processFunction limits m params body)
  Break → Break
 where
  goBlock = walkBlock limits m mode
  goAnn = fmap (walkExp limits m mode)
  goVar ∷ Annotated Comments VarF → Annotated Comments VarF
  goVar (c, v) =
    (c,) case v of
      VarName n → VarName n
      -- An assignment target is a write: even when its shape is a
      -- module-table field, only its subexpressions are rewritten.
      VarField e n → VarField (goAnn e) n
      VarIndex e1 e2 → VarIndex (goAnn e1) (goAnn e2)

walkExp ∷ LuaLimits → Name → WalkMode → Exp → Exp
walkExp limits m mode = \case
  moduleRead@(Var (c, VarField (Ann (Var (Ann (VarName t)))) field))
    | t == m
    , Region selected ← mode
    , Just cache ← Map.lookup field selected →
        Var (c, VarName cache)
    | otherwise → moduleRead
  Var (c, VarField e n) → Var (c, VarField (goAnn e) n)
  Var (c, VarIndex e1 e2) → Var (c, VarIndex (goAnn e1) (goAnn e2))
  Var (c, VarName n) → Var (c, VarName n)
  -- A zero-argument immediately-invoked function runs within the
  -- current activation: in a region its body belongs to that region.
  FunctionCall (fc, Function [] body) []
    | Region _selected ← mode →
        FunctionCall (fc, Function [] (walkBlock limits m mode body)) []
  Function params body →
    Function params (processFunction limits m params body)
  FunctionCall fn args → FunctionCall (goAnn fn) (goAnn <$> args)
  MethodCall obj n args → MethodCall (goAnn obj) n (goAnn <$> args)
  TableCtor rows → TableCtor (goRow <<$>> rows)
  UnOp op e → UnOp op (goAnn e)
  BinOp op e1 e2 → BinOp op (goAnn e1) (goAnn e2)
  Paren e → Paren (goAnn e)
  Nil → Nil
  Boolean b → Boolean b
  Integer i → Integer i
  Float d → Float d
  String s → String s
  Vararg → Vararg
 where
  goAnn = fmap (walkExp limits m mode)
  goRow ∷ TableRowF Comments → TableRowF Comments
  goRow = \case
    TableRowKV k v → TableRowKV (goAnn k) (goAnn v)
    TableRowNV n v → TableRowNV n (goAnn v)
    TableRowV v → TableRowV (goAnn v)

{- | Rewrite one function proto: select the module-table fields worth
caching in its region, prepend a single @local@ statement reading them
off the module table, and rewrite the region's reads to the cache
locals. Nested protos are processed recursively either way.
-}
processFunction
  ∷ LuaLimits → Name → [Annotated Comments ParamF] → Block → Block
processFunction limits m params body = case cached of
  [] → rewritten
  (c : cs) → cacheStatement (c :| cs) : rewritten
 where
  RegionInfo {fieldWeights, declaredLocals, iifeNames} =
    regionInfo m Always body

  budget =
    maxCachedFieldsPerFunction
      `min` (workingUpvalueCeiling limits - getMax iifeNames)
      `min` ( workingLocalCeiling limits
                - getSum declaredLocals
                - length params
            )

  eligible ∷ [Name]
  eligible =
    fmap fst
      . sortOn (\(field, Sum w) → (Down w, field))
      . filter ((>= 2) . getSum . snd)
      $ Map.toList fieldWeights

  cached ∷ [(Name, Name)]
  cached
    | budget <= 0 = []
    | otherwise = assignCacheNames taken (take budget eligible)
   where
    taken =
      namesInBlock body
        <> Set.fromList (mapMaybe (paramNamed . unAnn) params)
        <> Set.singleton m

  rewritten = walkBlock limits m (Region (Map.fromList cached)) body

  cacheStatement ∷ NonEmpty (Name, Name) → Annotated Comments StatementF
  cacheStatement pairs =
    ann $
      Local
        (snd <$> pairs)
        (toList pairs <&> \(field, _cache) → ann (varField (varName m) field))

-- | Pick a fresh local name for every selected field, in order.
assignCacheNames ∷ Set Name → [Name] → [(Name, Name)]
assignCacheNames _taken [] = []
assignCacheNames taken (field : rest) =
  (field, cache) : assignCacheNames (Set.insert cache taken) rest
 where
  cache =
    fromMaybe field . find (`Set.notMember` taken) $
      field : [suffixed i | i ← [1 ∷ Int ..]]
  -- The candidate list is infinite, so 'find' always succeeds; the
  -- 'fromMaybe' merely discharges the 'Maybe'.
  suffixed i = Name.unsafeName (Name.toText field <> "_c" <> show i)

--------------------------------------------------------------------------------
-- Region analysis -------------------------------------------------------------

{- | Facts about one function's activation region: the qualification
weight of each module-table field (see 'Ctx'), how many local slots
the region's declarations consume, and the largest name-set
over-approximation among looked-through IIFEs (the upvalue budget
input; 0 when the region has none).
-}
data RegionInfo = RegionInfo
  { fieldWeights ∷ Map Name (Sum Natural)
  , declaredLocals ∷ Sum Int
  , iifeNames ∷ Max Int
  }

instance Semigroup RegionInfo where
  RegionInfo w d i <> RegionInfo w' d' i' =
    RegionInfo (Map.unionWith (<>) w w') (d <> d') (i <> i')

instance Monoid RegionInfo where
  mempty = RegionInfo Map.empty mempty (Max 0)

{- | How often the code being walked executes relative to one entry of
the enclosing function. Entry-hoisting a read is a bet: it pays one
table read unconditionally to save the reads the body would perform.
The weight makes only favorable bets qualify — a read that re-executes
per loop iteration ('InLoop') weighs 2 (one iteration already breaks
even), a read on the unconditional spine of the body ('Always') weighs
1 (two such reads win), and a read inside a conditional branch
('Conditional') weighs 0: hoisting it would tax every activation for a
read that may never happen — measured as a ~25% regression on the
leaf-heavy naive-fib shape, where half the calls take the base-case
branch and the recursive reads sit in the other.
-}
data Ctx
  = InLoop
  | Always
  | Conditional

{- | Branches keep loop context (an iteration repeats them); otherwise
they execute conditionally.
-}
branch ∷ Ctx → Ctx
branch = \case
  InLoop → InLoop
  Always → Conditional
  Conditional → Conditional

readWeight ∷ Ctx → Natural
readWeight = \case
  InLoop → 2
  Always → 1
  Conditional → 0

regionInfo ∷ Name → Ctx → Block → RegionInfo
regionInfo m ctx = foldMap (statementInfo m ctx . unAnn)

statementInfo ∷ Name → Ctx → StatementF Comments → RegionInfo
statementInfo m ctx = \case
  Assign vars vals →
    foldMap (varInfo . unAnn) vars <> foldMap expInfo vals
  Local names vals → declared (length names) <> foldMap expInfo vals
  IfThenElse p tb eb → expInfo p <> branchInfo tb <> branchInfo eb
  Return es → foldMap expInfo es
  CallStatement e → expInfo e
  Do body → regionInfo m ctx body
  While p body → loopExpInfo p <> loopBlockInfo body
  Repeat body p → loopBlockInfo body <> loopExpInfo p
  ForNum _n start limit step body →
    declared 1
      <> expInfo start
      <> expInfo limit
      <> foldMap expInfo step
      <> loopBlockInfo body
  ForIn names es body →
    declared (length names) <> foldMap expInfo es <> loopBlockInfo body
  -- A nested proto: its reads are its own to cache, its locals are its
  -- own register space; only its name occupies a slot here.
  LocalFunction _n _params _body → declared 1
  Break → mempty
 where
  declared n = mempty {declaredLocals = Sum n}
  branchInfo = regionInfo m (branch ctx)
  expInfo = exprInfo m ctx . unAnn
  loopBlockInfo = regionInfo m InLoop
  loopExpInfo = exprInfo m InLoop . unAnn
  varInfo ∷ VarF Comments → RegionInfo
  varInfo = \case
    VarName _n → mempty
    VarField e _n → expInfo e
    VarIndex e1 e2 → expInfo e1 <> expInfo e2

exprInfo ∷ Name → Ctx → ExpF Comments → RegionInfo
exprInfo m ctx = \case
  Var (Ann (VarField (Ann (Var (Ann (VarName t)))) field))
    | t == m →
        mempty
          { fieldWeights = Map.singleton field (Sum (readWeight ctx))
          }
  Var (Ann v) → case v of
    VarName _n → mempty
    VarField e _n → goAnn e
    VarIndex e1 e2 → goAnn e1 <> goAnn e2
  FunctionCall (Ann (Function [] body)) [] →
    mempty {iifeNames = Max (Set.size (namesInBlock body))}
      <> regionInfo m ctx body
  -- A nested proto boundary: contributes nothing to this region.
  Function _params _body → mempty
  FunctionCall fn args → goAnn fn <> foldMap goAnn args
  MethodCall obj _n args → goAnn obj <> foldMap goAnn args
  TableCtor rows → foldMap (rowInfo . unAnn) rows
  UnOp _op e → goAnn e
  -- The right operand of and/or evaluates only when the left doesn't
  -- decide, so it is a conditional position.
  BinOp op e1 e2
    | op == And || op == Or →
        goAnn e1 <> exprInfo m (branch ctx) (unAnn e2)
  BinOp _op e1 e2 → goAnn e1 <> goAnn e2
  Paren e → goAnn e
  Nil → mempty
  Boolean _ → mempty
  Integer _ → mempty
  Float _ → mempty
  String _ → mempty
  Vararg → mempty
 where
  goAnn = exprInfo m ctx . unAnn
  rowInfo ∷ TableRowF Comments → RegionInfo
  rowInfo = \case
    TableRowKV k v → goAnn k <> goAnn v
    TableRowNV _n v → goAnn v
    TableRowV v → goAnn v

--------------------------------------------------------------------------------
-- Name collection -------------------------------------------------------------

{- | Every name referenced or declared anywhere in a block, nested
protos included. Used to keep cache names fresh: a colliding cache
local could capture references resolving to an outer scope, or be
shadowed mid-body by a later declaration of the same name. Field and
method names are not variables and are not collected.
-}
namesInBlock ∷ Block → Set Name
namesInBlock = foldMap (namesInStatement . unAnn)

namesInStatement ∷ StatementF Comments → Set Name
namesInStatement = \case
  Assign vars vals →
    foldMap (namesInVar . unAnn) vars <> foldMap goAnn vals
  Local names vals → Set.fromList (toList names) <> foldMap goAnn vals
  IfThenElse p tb eb → goAnn p <> namesInBlock tb <> namesInBlock eb
  Return es → foldMap goAnn es
  CallStatement e → goAnn e
  Do body → namesInBlock body
  While p body → goAnn p <> namesInBlock body
  Repeat body p → namesInBlock body <> goAnn p
  ForNum n start limit step body →
    Set.singleton n
      <> goAnn start
      <> goAnn limit
      <> foldMap goAnn step
      <> namesInBlock body
  ForIn names es body →
    Set.fromList (toList names) <> foldMap goAnn es <> namesInBlock body
  LocalFunction n params body →
    Set.singleton n <> namesInParams params <> namesInBlock body
  Break → mempty
 where
  goAnn = namesInExp . unAnn

namesInExp ∷ ExpF Comments → Set Name
namesInExp = \case
  Var (Ann v) → namesInVar v
  Function params body → namesInParams params <> namesInBlock body
  FunctionCall fn args → goAnn fn <> foldMap goAnn args
  MethodCall obj _n args → goAnn obj <> foldMap goAnn args
  TableCtor rows → foldMap (namesInRow . unAnn) rows
  UnOp _op e → goAnn e
  BinOp _op e1 e2 → goAnn e1 <> goAnn e2
  Paren e → goAnn e
  Nil → mempty
  Boolean _ → mempty
  Integer _ → mempty
  Float _ → mempty
  String _ → mempty
  Vararg → mempty
 where
  goAnn = namesInExp . unAnn
  namesInRow ∷ TableRowF Comments → Set Name
  namesInRow = \case
    TableRowKV k v → goAnn k <> goAnn v
    TableRowNV _n v → goAnn v
    TableRowV v → goAnn v

namesInVar ∷ VarF Comments → Set Name
namesInVar = \case
  VarName n → Set.singleton n
  VarField e _n → namesInExp (unAnn e)
  VarIndex e1 e2 → namesInExp (unAnn e1) <> namesInExp (unAnn e2)

namesInParams ∷ [Annotated Comments ParamF] → Set Name
namesInParams = Set.fromList . mapMaybe (paramNamed . unAnn)

paramNamed ∷ ParamF Comments → Maybe Name
paramNamed = \case
  ParamNamed n → Just n
  ParamUnused → Nothing
  ParamVararg → Nothing

--------------------------------------------------------------------------------
-- Stability precondition ------------------------------------------------------

{- | Whether the module table is provably frozen during any function
activation, making entry-hoisted field reads sound. Outside function
bodies (the module-init sequence) field writes are the expected
pattern; inside any function body every occurrence of the module-table
name must be a plain field read. Any other occurrence anywhere — a
bare reference (the table could be aliased or passed somewhere that
mutates it), a dynamic index, a field write inside a function, a
declaration shadowing the name — disqualifies the whole chunk. Only
hand-written FFI can produce such shapes; generated code cannot.
-}
moduleTableStable ∷ Name → Chunk → Bool
moduleTableStable m = all stableOutside
 where
  stableOutside ∷ StatementF Comments → Bool
  stableOutside = \case
    Assign vars vals →
      all (writeTarget . unAnn) vars && all goAnn vals
    -- The module table's own declaration (@local M = {}@) and any
    -- other top-level declaration may legitimately bind the name.
    Local _names vals → all goAnn vals
    IfThenElse p tb eb →
      goAnn p && allOutside tb && allOutside eb
    Return es → all goAnn es
    CallStatement e → goAnn e
    Do body → allOutside body
    While p body → goAnn p && allOutside body
    Repeat body p → allOutside body && goAnn p
    ForNum n start limit step body →
      n /= m
        && goAnn start
        && goAnn limit
        && all goAnn step
        && allOutside body
    ForIn names es body →
      notElem m names && all goAnn es && allOutside body
    LocalFunction n params body →
      n /= m && paramsStable params && all (stableInside . unAnn) body
    Break → True
   where
    allOutside = all (stableOutside . unAnn)
    goAnn = stableExp . unAnn
    -- Outside a function, writing a module-table field is module init.
    writeTarget ∷ VarF Comments → Bool
    writeTarget = \case
      VarName n → n /= m
      VarField (Ann (Var (Ann (VarName _t)))) _n → True
      VarField e _n → stableExp (unAnn e)
      VarIndex e1 e2 → stableExp (unAnn e1) && stableExp (unAnn e2)

  stableInside ∷ StatementF Comments → Bool
  stableInside = \case
    Assign vars vals →
      all (writeTarget . unAnn) vars && all goAnn vals
    Local names vals → notElem m names && all goAnn vals
    IfThenElse p tb eb → goAnn p && allInside tb && allInside eb
    Return es → all goAnn es
    CallStatement e → goAnn e
    Do body → allInside body
    While p body → goAnn p && allInside body
    Repeat body p → allInside body && goAnn p
    ForNum n start limit step body →
      n /= m
        && goAnn start
        && goAnn limit
        && all goAnn step
        && allInside body
    ForIn names es body →
      notElem m names && all goAnn es && allInside body
    LocalFunction n params body →
      n /= m && paramsStable params && allInside body
    Break → True
   where
    allInside = all (stableInside . unAnn)
    goAnn = stableExp . unAnn
    -- Inside a function no module-table field may be written.
    writeTarget ∷ VarF Comments → Bool
    writeTarget = \case
      VarName n → n /= m
      VarField (Ann (Var (Ann (VarName t)))) _n → t /= m
      VarField e _n → stableExp (unAnn e)
      VarIndex e1 e2 → stableExp (unAnn e1) && stableExp (unAnn e2)

  -- Expression positions are reads at any level: the module-table name
  -- may appear only as the base of a field read.
  stableExp ∷ ExpF Comments → Bool
  stableExp = \case
    Var (Ann v) → case v of
      VarName n → n /= m
      VarField (Ann (Var (Ann (VarName _t)))) _n → True
      VarField e _n → stableExp (unAnn e)
      VarIndex e1 e2 → stableExp (unAnn e1) && stableExp (unAnn e2)
    Function params body →
      paramsStable params && all (stableInside . unAnn) body
    FunctionCall fn args → goAnn fn && all goAnn args
    MethodCall obj _n args → goAnn obj && all goAnn args
    TableCtor rows → all (stableRow . unAnn) rows
    UnOp _op e → goAnn e
    BinOp _op e1 e2 → goAnn e1 && goAnn e2
    Paren e → goAnn e
    Nil → True
    Boolean _ → True
    Integer _ → True
    Float _ → True
    String _ → True
    Vararg → True
   where
    goAnn = stableExp . unAnn
    stableRow ∷ TableRowF Comments → Bool
    stableRow = \case
      TableRowKV k v → goAnn k && goAnn v
      TableRowNV _n v → goAnn v
      TableRowV v → goAnn v

  paramsStable ∷ [Annotated Comments ParamF] → Bool
  paramsStable = notElem (Just m) . fmap (paramNamed . unAnn)
