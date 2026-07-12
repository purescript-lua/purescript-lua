{- | Two-tier storage of top-level bindings (issue #174, stage 2).

Every top-level binding lives in the module-scope table @M@
('Language.PureScript.Backend.Lua.Fixture.moduleName'), so every
inter-binding reference is a hash lookup. This pass promotes the
most-referenced bindings to real chunk locals — @M.foo = e@ becomes
@local foo = e@ and the reads become local\/upvalue accesses — with @M@
kept as the overflow valve: every budget overflow degrades the specific
binding or reference back to today's module-table form, so the worst
case is exactly the input chunk and the target's per-function limits
(the constraint that motivated the module table, issue #19) stay
handled by construction. A chunk whose bindings and references all fit
the budgets loses the @M@ table entirely.

== Locals budget: which bindings are promoted

A binding qualifies for promotion when its field is initialized by
exactly one top-level @M.x = e@ statement, is read at least once, and
its name is not used as a variable anywhere in the chunk (a promoted
local keeps the field's name; instead of renaming around a collision
the pass declines — only hand-written FFI produces colliding names).
Qualifying bindings are ranked by static read count and promoted
top-first while the chunk's local slots — pre-existing declarations
plus one per promotion — stay under
'Language.PureScript.Backend.Lua.Limits.workingLocalCeiling'. The rest
keep their @M.x@ form.

== Upvalue budget: which references are demoted

Chunk locals read inside nested functions cost upvalue slots, and in
Lua 5.1 a nested function reading an outer local costs a slot in every
intermediate function (pass-through accumulation) — the failure mode
that killed the original locals-based codegen (issue #19). The pass
computes every function proto's upvalue demand bottom-up:

> demand(f) = ownOuterRefs(f) ∪ { b ∈ demand(child) | b not bound by f }

counting all outer-local references (function-level locals and
parameters included), with lexical positions respected — a name
referenced before its declaration resolves outside it. When a proto's
demand would exceed
'Language.PureScript.Backend.Lua.Limits.workingUpvalueCeiling',
promoted-binding references within that proto's subtree are demoted —
printed as @M.x@ again — cheapest reads first, until the proto fits.
The binding itself stays a local for everyone else and is mirrored
into the module table (@M.x = x@ right after @local x = e@) so the
demoted reads still find it. Demotion swaps a named upvalue for the
@M@ upvalue, so once @M@ is in a proto's demand set each further
demotion shrinks it by one; a proto over budget on real function
locals alone (not promoted bindings) is beyond this pass's remit and
is left as is — exactly as over budget as the input chunk.

== Recursion and declaration order

A promoted binding read before its initializer — the self-reference of
a recursive function, or an earlier member of a mutually recursive
group — would resolve to a global under plain @local x = e@ ordering
(a Lua local scopes from its declaration onward). Such bindings are
pre-declared: @local x@ is emitted before the first referencing
statement and the initializer becomes a plain assignment. Only the
forward-referenced members are pre-declared.

== Preconditions

The pass rewrites nothing unless the module table is provably stable —
'moduleTableStable', the same precondition stage 1
("Language.PureScript.Backend.Lua.Localize") checks: inside function
bodies every occurrence of @M@ is a plain field read, and outside them
field writes are the module-init sequence. On top of that the chunk
must declare @M@ exactly once, as @local M = {}@, before any other
occurrence of the name. Anything else — only hand-written FFI can
produce it — leaves the chunk unchanged.

The pass runs before stage 1 in
'Language.PureScript.Backend.Lua.Optimizer.optimizeChunk': whatever
stays in @M@ after promotion (the tail plus demoted references) is
exactly what per-function caching still speeds up.

The full design history — locals, then the @M@ table, then this
two-tier form — is recorded in
@docs/adr/0001-top-level-binding-storage.md@.
-}
module Language.PureScript.Backend.Lua.Promote
  ( promoteChunk
  ) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.Lua.Limits
  ( LuaLimits
  , workingLocalCeiling
  , workingUpvalueCeiling
  )
import Language.PureScript.Backend.Lua.Localize
  ( moduleTableStable
  , namesInBlock
  )
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Types
  ( Annotated
  , Chunk
  , Comments
  , ExpF (..)
  , ParamF (..)
  , Statement
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  , ann
  , assign
  , unAnn
  , varName
  , pattern Ann
  )

type Block = [Annotated Comments StatementF]

{- | Promote top-level module-table bindings to chunk locals, budgeting
against the given target limits. The 'Name' argument is the
module-table name ('Language.PureScript.Backend.Lua.Fixture.moduleName').
Returns the chunk unchanged when the preconditions do not hold or no
binding fits the budgets — see the module documentation.
-}
promoteChunk ∷ LuaLimits → Name → Chunk → Chunk
promoteChunk limits m chunk = fromMaybe chunk do
  declIndex ← moduleTableDeclIndex m chunk
  guard $ moduleTableStable m chunk
  let initializers = fieldInits m chunk
      readCounts = fieldReadCounts m chunk
      readCountOf x = Map.findWithDefault 0 x readCounts
      taken = namesInBlock (ann <$> chunk)
      budget = workingLocalCeiling limits - topLevelLocalSlots chunk
      candidates =
        sortOn
          (\(x, i) → (Down (readCountOf x), i))
          [ (x, i)
          | (x, Just i) ← Map.toList initializers
          , x `Set.notMember` taken
          , readCountOf x > 0
          ]
      promoted = Map.fromList (take budget candidates)
  guard $ not (Map.null promoted)
  let analysis = analyzeChunk m (Map.keysSet promoted) chunk
      demotions =
        planDemotions (workingUpvalueCeiling limits) promoted analysis
      mirrored = Set.unions (Map.elems demotions)
      demotedSite (x, _i, path) =
        any (\p → x `Set.member` demotionsAt p) path
       where
        demotionsAt p = Map.findWithDefault mempty p demotions
      earliestLocalRead =
        Map.fromListWith
          min
          [(x, i) | site@(x, i, _path) ← readSites analysis, not (demotedSite site)]
      forwardDeclared =
        Map.keysSet $
          Map.filterWithKey
            (\x i → maybe False (i <=) (Map.lookup x promoted))
            earliestLocalRead
      moduleTableSurvives =
        not (Set.null mirrored)
          || any (\(x, _) → x `Map.notMember` promoted) (Map.toList initializers)
          || any
            (\(x, c) → c > 0 && x `Map.notMember` promoted)
            (Map.toList readCounts)
  pure $
    rewriteChunk
      RewritePlan
        { planModuleTable = m
        , planPromoted = promoted
        , planDemoted = demotions
        , planMirrored = mirrored
        , planForwardDeclared = forwardDeclared
        , planPreDeclarations =
            Map.fromListWith
              (<>)
              [ (i, [x])
              | (x, i) ← Map.toList earliestLocalRead
              , x `Set.member` forwardDeclared
              ]
        , planDeclIndex = declIndex
        , planKeepDecl = moduleTableSurvives
        }
      chunk

--------------------------------------------------------------------------------
-- Candidate selection ---------------------------------------------------------

{- | The index of the canonical module-table declaration
(@local M = {}@). 'Nothing' when the chunk declares the name more than
once, in another shape, or mentions it before the declaration (such a
mention would reference a different, global @M@).
-}
moduleTableDeclIndex ∷ Name → Chunk → Maybe Int
moduleTableDeclIndex m chunk = do
  [(i, decl)] ← pure [(i, s) | (i, s) ← zip [0 ..] chunk, declaresName s]
  Local (_ :| []) [Ann (TableCtor [])] ← pure decl
  guard $ m `Set.notMember` namesInBlock (ann <$> take i chunk)
  pure i
 where
  declaresName = \case
    Local names _vals → m `elem` names
    LocalFunction n _params _body → n == m
    _ → False

{- | Every module-table field written at top level, mapped to its
initializer's statement index. A field keeps its index only when it is
written exactly once, by a single-target single-value @M.x = e@
statement; any other write shape (or a second write) maps the field to
'Nothing' — out of promotion but still on record, since its write
keeps the module table alive.
-}
fieldInits ∷ Name → Chunk → Map Name (Maybe Int)
fieldInits m chunk = Map.fromListWith (\_ _ → Nothing) do
  (i, stmt) ← zip [0 ..] chunk
  Assign vars vals ← pure stmt
  case (vars, vals) of
    ((_, VarField (Ann (Var (Ann (VarName t)))) x) :| [], _ :| [])
      | t == m → pure (x, Just i)
    _ →
      [ (x, Nothing)
      | (unAnn → VarField (Ann (Var (Ann (VarName t)))) x) ← toList vars
      , t == m
      ]

-- | Static count of module-table field reads across the whole chunk.
fieldReadCounts ∷ Name → Chunk → Map Name Int
fieldReadCounts m chunk = execState (traverse_ goStmt chunk) Map.empty
 where
  goStmt ∷ Statement → State (Map Name Int) ()
  goStmt = \case
    Assign vars vals →
      traverse_ (goWrite . unAnn) vars *> traverse_ goExp vals
    Local _names vals → traverse_ goExp vals
    IfThenElse p tb eb → goExp p *> goBlock tb *> goBlock eb
    Return es → traverse_ goExp es
    CallStatement e → goExp e
    Do body → goBlock body
    While p body → goExp p *> goBlock body
    Repeat body p → goBlock body *> goExp p
    ForNum _n start limit step body →
      goExp start *> goExp limit *> traverse_ goExp step *> goBlock body
    ForIn _names es body → traverse_ goExp es *> goBlock body
    LocalFunction _n _params body → goBlock body
    Break → pass
  goBlock = traverse_ (goStmt . unAnn)
  goExp (unAnn → e) = case e of
    Var (Ann v) → goRead v
    Function _params body → goBlock body
    FunctionCall fn args → goExp fn *> traverse_ goExp args
    MethodCall obj _n args → goExp obj *> traverse_ goExp args
    TableCtor rows → traverse_ (goRow . unAnn) rows
    UnOp _op e1 → goExp e1
    BinOp _op e1 e2 → goExp e1 *> goExp e2
    Paren e1 → goExp e1
    Nil → pass
    Boolean _ → pass
    Integer _ → pass
    Float _ → pass
    String _ → pass
    Vararg → pass
  goRow = \case
    TableRowKV k v → goExp k *> goExp v
    TableRowNV _n v → goExp v
    TableRowV v → goExp v
  goRead = \case
    VarField (Ann (Var (Ann (VarName t)))) x
      | t == m → modify' (Map.insertWith (+) x 1)
    VarField e _n → goExp e
    VarIndex e1 e2 → goExp e1 *> goExp e2
    VarName _n → pass
  -- An assignment target is a write, not a read: only its
  -- subexpressions count.
  goWrite = \case
    VarField (Ann (Var (Ann (VarName t)))) _x | t == m → pass
    VarField e _n → goExp e
    VarIndex e1 e2 → goExp e1 *> goExp e2
    VarName _n → pass

{- | Local slots the chunk's main function already spends before any
promotion: every top-level declaration, loop control variables
included (they occupy main-function registers even though their scope
is the loop body).
-}
topLevelLocalSlots ∷ Chunk → Int
topLevelLocalSlots =
  sum . fmap \case
    Local names _vals → length names
    LocalFunction {} → 1
    ForNum {} → 1
    ForIn names _es _body → length names
    _ → 0

--------------------------------------------------------------------------------
-- Reference analysis ----------------------------------------------------------

-- Both the analysis walk below and the rewrite walk at the bottom of
-- this module number function protos with a running counter in
-- traversal order. They must visit statement and expression fields in
-- exactly the same order, or demotion sets computed here would apply
-- to the wrong protos there.

type ProtoId = Int

{- | What a reference resolves to. Two-tier accounting only ever demotes
'BField' references; everything else is recorded so that proto demand
sets are complete.
-}
data Binder
  = -- | A promoted binding's chunk local
    BField Name
  | -- | The module table itself
    BTable
  | -- | Any other chunk-level local (fixtures, loop variables)
    BTop Name
  | -- | A local (or parameter) of the given function proto
    BLoc ProtoId Name
  deriving stock (Eq, Ord, Show)

-- | 'Nothing' means the binder lives at chunk level.
binderOwner ∷ Binder → Maybe ProtoId
binderOwner = \case
  BLoc p _n → Just p
  _ → Nothing

data Analysis = Analysis
  { nextProto ∷ ProtoId
  , ownRefs ∷ Map ProtoId (Set Binder)
  {- ^ Outer binders referenced directly in a proto's own body
  (nested protos excluded)
  -}
  , ownCounts ∷ Map ProtoId (Map Name Int)
  -- ^ Promoted-field reads in a proto's own body
  , protoKids ∷ Map ProtoId [ProtoId]
  , protosBottomUp ∷ [ProtoId]
  {- ^ Reverse discovery order: every proto precedes its ancestors, so
  a left-to-right pass processes children before parents
  -}
  , readSites ∷ [(Name, Int, [ProtoId])]
  {- ^ Promoted-field read sites: field, top-level statement index,
  proto path (innermost first; empty at top level)
  -}
  }

-- | Lexical environment: name → binder, updated in statement order.
type Env = Map Name Binder

analyzeChunk ∷ Name → Set Name → Chunk → Analysis
analyzeChunk m promoted chunk =
  execState
    (foldlM (\env (i, s) → aStmt env [] i s) Map.empty (zip [0 ..] chunk))
    Analysis
      { nextProto = 0
      , ownRefs = Map.empty
      , ownCounts = Map.empty
      , protoKids = Map.empty
      , protosBottomUp = []
      , readSites = []
      }
 where
  bindLocal ∷ [ProtoId] → Name → Binder
  bindLocal path n
    | n == m = BTable
    | otherwise = case path of
        [] → BTop n
        cur : _ → BLoc cur n

  bindAll ∷ [ProtoId] → Env → [Name] → Env
  bindAll path = foldl' \e n → Map.insert n (bindLocal path n) e

  aBlock ∷ Env → [ProtoId] → Int → Block → State Analysis Env
  aBlock env path i = foldlM (\e s → aStmt e path i (unAnn s)) env

  aStmt ∷ Env → [ProtoId] → Int → Statement → State Analysis Env
  aStmt env path i = \case
    Assign vars vals → do
      traverse_ (aWrite env path i . unAnn) vars
      traverse_ (aExp env path i) vals
      pure env
    Local names vals → do
      -- Initializers see the outer bindings: `local x = e` resolves
      -- x inside e outside this statement.
      traverse_ (aExp env path i) vals
      pure $ bindAll path env (toList names)
    IfThenElse p tb eb → do
      aExp env path i p
      void $ aBlock env path i tb
      void $ aBlock env path i eb
      pure env
    Return es → traverse_ (aExp env path i) es $> env
    CallStatement e → aExp env path i e $> env
    Do body → void (aBlock env path i body) $> env
    While p body → do
      aExp env path i p
      void $ aBlock env path i body
      pure env
    Repeat body p → do
      -- The until-condition is in the body's scope.
      env' ← aBlock env path i body
      aExp env' path i p
      pure env
    ForNum n start limit step body → do
      aExp env path i start
      aExp env path i limit
      traverse_ (aExp env path i) step
      void $ aBlock (bindAll path env [n]) path i body
      pure env
    ForIn names es body → do
      traverse_ (aExp env path i) es
      void $ aBlock (bindAll path env (toList names)) path i body
      pure env
    LocalFunction n params body → do
      -- The name is in scope inside the body (self-recursion) and
      -- belongs to the enclosing scope.
      let env' = bindAll path env [n]
      aProto env' path i params body
      pure env'
    Break → pure env

  aProto
    ∷ Env
    → [ProtoId]
    → Int
    → [Annotated Comments ParamF]
    → Block
    → State Analysis ()
  aProto env path i params body = do
    pid ← state \st →
      ( nextProto st
      , st
          { nextProto = nextProto st + 1
          , protoKids = case path of
              [] → protoKids st
              cur : _ → Map.insertWith (<>) cur [nextProto st] (protoKids st)
          , protosBottomUp = nextProto st : protosBottomUp st
          }
      )
    let bindParam e = \case
          ParamNamed n → Map.insert n (BLoc pid n) e
          ParamUnused → e
          ParamVararg → e
    void $
      aBlock
        (foldl' (\e p → bindParam e (unAnn p)) env params)
        (pid : path)
        i
        body

  aExp ∷ Env → [ProtoId] → Int → Annotated Comments ExpF → State Analysis ()
  aExp env path i (unAnn → e) = case e of
    Var (Ann v) → aRead env path i v
    Function params body → aProto env path i params body
    FunctionCall fn args → go fn *> traverse_ go args
    MethodCall obj _n args → go obj *> traverse_ go args
    TableCtor rows → traverse_ (aRow . unAnn) rows
    UnOp _op e1 → go e1
    BinOp _op e1 e2 → go e1 *> go e2
    Paren e1 → go e1
    Nil → pass
    Boolean _ → pass
    Integer _ → pass
    Float _ → pass
    String _ → pass
    Vararg → pass
   where
    go = aExp env path i
    aRow = \case
      TableRowKV k v → go k *> go v
      TableRowNV _n v → go v
      TableRowV v → go v

  aRead ∷ Env → [ProtoId] → Int → VarF Comments → State Analysis ()
  aRead env path i = \case
    VarField (Ann (Var (Ann (VarName t)))) x
      | t == m →
          if x `Set.member` promoted
            then recordFieldRead path i x
            else recordRef path BTable
    VarField e _n → aExp env path i e
    VarIndex e1 e2 → aExp env path i e1 *> aExp env path i e2
    VarName n → whenJust (Map.lookup n env) (recordRef path)

  -- An assignment target: a write also demands an upvalue slot when
  -- it targets an outer local, and its subexpressions are reads.
  aWrite ∷ Env → [ProtoId] → Int → VarF Comments → State Analysis ()
  aWrite env path i = \case
    VarField (Ann (Var (Ann (VarName t)))) _x | t == m → pass
    VarField e _n → aExp env path i e
    VarIndex e1 e2 → aExp env path i e1 *> aExp env path i e2
    VarName n → whenJust (Map.lookup n env) (recordRef path)

  recordFieldRead ∷ [ProtoId] → Int → Name → State Analysis ()
  recordFieldRead path i x = modify' \st →
    st
      { readSites = (x, i, path) : readSites st
      , ownRefs = case path of
          [] → ownRefs st
          cur : _ →
            Map.insertWith (<>) cur (Set.singleton (BField x)) (ownRefs st)
      , ownCounts = case path of
          [] → ownCounts st
          cur : _ →
            Map.insertWith
              (Map.unionWith (+))
              cur
              (Map.singleton x 1)
              (ownCounts st)
      }

  recordRef ∷ [ProtoId] → Binder → State Analysis ()
  recordRef path b = case path of
    [] → pass
    cur : _ →
      unless (binderOwner b == Just cur) $ modify' \st →
        st {ownRefs = Map.insertWith (<>) cur (Set.singleton b) (ownRefs st)}

--------------------------------------------------------------------------------
-- Demotion planning -----------------------------------------------------------

{- | Decide, bottom-up over the proto tree, which promoted-field
references must degrade back to @M.x@ form: at every proto whose
upvalue demand exceeds the ceiling, field references within its
subtree are demoted cheapest-first (by subtree read count, ties to the
earlier-declared field) until the proto fits. Demoting swaps the field
for @M@ in the demand set, so the first demotion is free only when @M@
is already demanded.
-}
planDemotions
  ∷ Int
  -- ^ Upvalue ceiling
  → Map Name Int
  -- ^ Promoted fields with their declaration order (initializer index)
  → Analysis
  → Map ProtoId (Set Name)
planDemotions upvalueCeiling declOrder analysis =
  go Map.empty Map.empty Map.empty (protosBottomUp analysis)
 where
  go demand subCounts demotions = \case
    [] → demotions
    p : rest →
      let kids = Map.findWithDefault [] p (protoKids analysis)
          sub =
            Map.unionsWith
              (+)
              ( Map.findWithDefault mempty p (ownCounts analysis)
                  : fmap (\k → Map.findWithDefault mempty k subCounts) kids
              )
          demand0 =
            Set.filter (\b → binderOwner b /= Just p) $
              Set.unions
                ( Map.findWithDefault mempty p (ownRefs analysis)
                    : fmap (\k → Map.findWithDefault mempty k demand) kids
                )
          demotable =
            sortOn
              (\x → (Map.findWithDefault 0 x sub, Map.lookup x declOrder))
              [x | BField x ← toList demand0]
          (demandFinal, demoted)
            | Set.size demand0 <= upvalueCeiling = (demand0, [])
            | otherwise = demote demand0 demotable []
       in go
            (Map.insert p demandFinal demand)
            (Map.insert p sub subCounts)
            ( if null demoted
                then demotions
                else Map.insert p (Set.fromList demoted) demotions
            )
            rest

  demote s candidates acc = case candidates of
    _ | Set.size s <= upvalueCeiling → (s, acc)
    [] → (s, acc)
    x : rest →
      demote (Set.insert BTable (Set.delete (BField x) s)) rest (x : acc)

--------------------------------------------------------------------------------
-- Rewrite ---------------------------------------------------------------------

data RewritePlan = RewritePlan
  { planModuleTable ∷ Name
  , planPromoted ∷ Map Name Int
  -- ^ Promoted fields with their initializer's statement index
  , planDemoted ∷ Map ProtoId (Set Name)
  , planMirrored ∷ Set Name
  {- ^ Fields with at least one demoted read: their locals are
  mirrored into the module table
  -}
  , planForwardDeclared ∷ Set Name
  {- ^ Fields read (as locals) before their initializer: pre-declared,
  initialized by plain assignment
  -}
  , planPreDeclarations ∷ Map Int [Name]
  -- ^ Pre-declarations to emit before the given top-level statement
  , planDeclIndex ∷ Int
  , planKeepDecl ∷ Bool
  }

-- See the traversal-order note above 'ProtoId': this walk numbers
-- protos exactly like the analysis walk.
rewriteChunk ∷ RewritePlan → Chunk → Chunk
rewriteChunk RewritePlan {..} chunk =
  concat $ evalState (traverse rwTop (zip [0 ..] chunk)) 0
 where
  m = planModuleTable

  rwTop ∷ (Int, Statement) → State ProtoId [Statement]
  rwTop (i, stmt) = do
    body ←
      if
        | i == planDeclIndex →
            pure [stmt | planKeepDecl]
        | Assign
            ((_, VarField (Ann (Var (Ann (VarName t)))) x) :| [])
            (v :| []) ←
            stmt
        , t == m
        , Just initIndex ← Map.lookup x planPromoted
        , initIndex == i → do
            v' ← rwAnnExp mempty v
            let bind
                  | x `Set.member` planForwardDeclared =
                      Assign (ann (VarName x) :| []) (v' :| [])
                  | otherwise = Local (x :| []) [v']
                mirror =
                  [ assign (VarField (ann (varName m)) x) (varName x)
                  | x `Set.member` planMirrored
                  ]
            pure (bind : mirror)
        | otherwise →
            one <$> rwStmt mempty stmt
    pure (preDeclarations <> body)
   where
    preDeclarations =
      [ Local (x :| []) []
      | x ←
          sortOn
            (`Map.lookup` planPromoted)
            (Map.findWithDefault [] i planPreDeclarations)
      ]

  demotionsAt ∷ ProtoId → Set Name
  demotionsAt p = Map.findWithDefault mempty p planDemoted

  enterProto ∷ Set Name → State ProtoId (Set Name)
  enterProto demoted = state \pid →
    (demoted <> demotionsAt pid, pid + 1)

  rwBlock ∷ Set Name → Block → State ProtoId Block
  rwBlock demoted = traverse (traverse (rwStmt demoted))

  rwStmt ∷ Set Name → Statement → State ProtoId Statement
  rwStmt demoted = \case
    Assign vars vals →
      Assign
        <$> traverse (traverse (rwWrite demoted)) vars
        <*> traverse (rwAnnExp demoted) vals
    Local names vals → Local names <$> traverse (rwAnnExp demoted) vals
    IfThenElse p tb eb →
      IfThenElse
        <$> rwAnnExp demoted p
        <*> rwBlock demoted tb
        <*> rwBlock demoted eb
    Return es → Return <$> traverse (rwAnnExp demoted) es
    CallStatement e → CallStatement <$> rwAnnExp demoted e
    Do body → Do <$> rwBlock demoted body
    While p body → While <$> rwAnnExp demoted p <*> rwBlock demoted body
    Repeat body p → Repeat <$> rwBlock demoted body <*> rwAnnExp demoted p
    ForNum n start limit step body →
      ForNum n
        <$> rwAnnExp demoted start
        <*> rwAnnExp demoted limit
        <*> traverse (rwAnnExp demoted) step
        <*> rwBlock demoted body
    ForIn names es body →
      ForIn names
        <$> traverse (rwAnnExp demoted) es
        <*> rwBlock demoted body
    LocalFunction n params body → do
      demoted' ← enterProto demoted
      LocalFunction n params <$> rwBlock demoted' body
    Break → pure Break

  rwAnnExp
    ∷ Set Name
    → Annotated Comments ExpF
    → State ProtoId (Annotated Comments ExpF)
  rwAnnExp demoted (c, e) = (c,) <$> rwExp demoted e

  rwExp ∷ Set Name → ExpF Comments → State ProtoId (ExpF Comments)
  rwExp demoted = \case
    moduleRead@(Var (c, VarField (Ann (Var (Ann (VarName t)))) x))
      | t == m
      , x `Map.member` planPromoted →
          pure
            if x `Set.member` demoted
              then moduleRead
              else Var (c, VarName x)
    Var (c, v) → Var . (c,) <$> rwRead demoted v
    Function params body → do
      demoted' ← enterProto demoted
      Function params <$> rwBlock demoted' body
    FunctionCall fn args →
      FunctionCall
        <$> rwAnnExp demoted fn
        <*> traverse (rwAnnExp demoted) args
    MethodCall obj n args →
      MethodCall
        <$> rwAnnExp demoted obj
        <*> pure n
        <*> traverse (rwAnnExp demoted) args
    TableCtor rows → TableCtor <$> traverse (traverse rwRow) rows
    UnOp op e → UnOp op <$> rwAnnExp demoted e
    BinOp op e1 e2 →
      BinOp op <$> rwAnnExp demoted e1 <*> rwAnnExp demoted e2
    Paren e → Paren <$> rwAnnExp demoted e
    Nil → pure Nil
    Boolean b → pure (Boolean b)
    Integer i → pure (Integer i)
    Float d → pure (Float d)
    String s → pure (String s)
    Vararg → pure Vararg
   where
    rwRow = \case
      TableRowKV k v →
        TableRowKV <$> rwAnnExp demoted k <*> rwAnnExp demoted v
      TableRowNV n v → TableRowNV n <$> rwAnnExp demoted v
      TableRowV v → TableRowV <$> rwAnnExp demoted v

  rwRead ∷ Set Name → VarF Comments → State ProtoId (VarF Comments)
  rwRead demoted = \case
    VarField e n → VarField <$> rwAnnExp demoted e <*> pure n
    VarIndex e1 e2 →
      VarIndex <$> rwAnnExp demoted e1 <*> rwAnnExp demoted e2
    v@(VarName _) → pure v

  -- An assignment target: a promoted field's initializer and mirror
  -- are built in 'rwTop'; any other module-table field target keeps
  -- its form, and only subexpressions are rewritten.
  rwWrite ∷ Set Name → VarF Comments → State ProtoId (VarF Comments)
  rwWrite demoted = \case
    v@(VarField (Ann (Var (Ann (VarName t)))) _x) | t == m → pure v
    v → rwRead demoted v
