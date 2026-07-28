{- | Emission-time renumbering of compiler-minted local names.

Fresh names are minted throughout the pipeline by drawing an index from a
monotone supply: suffix-minted as @base$N@ (uniquification, inline-paste
freshening, deep-bind flattening) or prefix-minted as @$tagN@ (CSE's
@$cse@, codegen's @$sel@\/@$a@ dispatch locals, the native-loop @$xs@\/@$f@
atomizers, …), with 'Language.PureScript.Backend.Lua.Name.makeSafe'
mangling @$@ to @_S_@ on the way into the Lua AST.

'renumberChunk' erases that history immediately before printing: every
supply-drawn index occurring in a local binder is renumbered in
first-occurrence order, and the binder's references follow
scope-consistently. Emitted names become a function of the chunk's own
structure — byte-stable under any upstream change that only perturbs
supply consumption. See Note [Supply-drawn digit runs] in
"Language.PureScript.Backend.Renumber" for which digit runs qualify.

PureScript identifiers cannot contain @$@, so compiler-minted names are
the only source of the renumbered shapes; a hand-written FFI local that
happens to spell one is renumbered too, which alpha-renames it
consistently and is semantically inert. Binders are renamed together
with exactly their in-scope references, so the rewrite is an
alpha-renaming; a reference the environment does not bind is a global —
an FFI file's stdlib or host-API read — and stays untouched, with
allocation skipping any index whose direct @prefix_S_index@ spelling
occurs free in the chunk, so a renamed binder cannot capture such a
global either.
-}
module Language.PureScript.Backend.Lua.Renumber (renumberChunk) where

import Data.Map qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name
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
  )
import Language.PureScript.Backend.Renumber
  ( Allocation
  , Delimiter (Delimiter)
  , noAllocation
  , renumberedText
  )

--------------------------------------------------------------------------------
-- Renumbering pass ------------------------------------------------------------

-- | Original binder name → renumbered name, for the binders in scope.
type Env = Map Name Name

type M = State Allocation

{- | Renumber every supply-drawn digit run occurring in a local binder —
'Local', 'LocalFunction', 'ForNum', 'ForIn' and function parameters — in
first-occurrence order, rewriting the binder's references along. Names
without a supply-drawn run, field and method names, table keys, and
global (unbound) references pass through unchanged. Idempotent: the
image of the pass is a fixpoint.
-}
renumberChunk ∷ Chunk → Chunk
renumberChunk chunk =
  evaluatingState noAllocation (goStatements Map.empty chunk)
 where
  free = freeVarNames chunk

  goStatements ∷ Env → [Statement] → M [Statement]
  goStatements env = \case
    [] → pure []
    s : rest → do
      (env', s') ← goStatement env s
      (s' :) <$> goStatements env' rest

  -- Returns the environment extended with the block's own declarations,
  -- which 'Repeat' feeds to its until-condition.
  goBlock
    ∷ Env
    → [Annotated Comments StatementF]
    → M (Env, [Annotated Comments StatementF])
  goBlock env = \case
    [] → pure (env, [])
    (c, s) : rest → do
      (env', s') ← goStatement env s
      (envFinal, rest') ← goBlock env' rest
      pure (envFinal, (c, s') : rest')

  goStatement ∷ Env → Statement → M (Env, Statement)
  goStatement env = \case
    Local names values → do
      -- Initializers are evaluated before any name binds.
      values' ← traverse (goExpA env) values
      (env', names') ← bindNames env names
      pure (env', Local names' values')
    LocalFunction fname params body → do
      -- The function name is in scope inside its own body.
      (env', fname') ← bindName env fname
      (bodyEnv, params') ← bindParams env' params
      (_, body') ← goBlock bodyEnv body
      pure (env', LocalFunction fname' params' body')
    Assign vars vals →
      (env,)
        <$> ( Assign
                <$> traverse (goVar env) vars
                <*> traverse (goExpA env) vals
            )
    IfThenElse p tb eb →
      (env,)
        <$> ( IfThenElse
                <$> goExpA env p
                <*> (snd <$> goBlock env tb)
                <*> (snd <$> goBlock env eb)
            )
    Return es → (env,) . Return <$> traverse (goExpA env) es
    CallStatement e → (env,) . CallStatement <$> goExpA env e
    Do body → (env,) . Do . snd <$> goBlock env body
    While p body →
      (env,) <$> (While <$> goExpA env p <*> (snd <$> goBlock env body))
    Repeat body p → do
      -- The until-condition is in scope of the body's locals.
      (bodyEnv, body') ← goBlock env body
      p' ← goExpA bodyEnv p
      pure (env, Repeat body' p')
    ForNum n start limit step body → do
      start' ← goExpA env start
      limit' ← goExpA env limit
      step' ← traverse (goExpA env) step
      (bodyEnv, n') ← bindName env n
      body' ← snd <$> goBlock bodyEnv body
      pure (env, ForNum n' start' limit' step' body')
    ForIn names es body → do
      es' ← traverse (goExpA env) es
      (bodyEnv, names') ← bindNames env names
      body' ← snd <$> goBlock bodyEnv body
      pure (env, ForIn names' es' body')
    Break → pure (env, Break)

  goExpA ∷ Env → Annotated Comments ExpF → M (Annotated Comments ExpF)
  goExpA env = traverse (goExp env)

  goExp ∷ Env → Exp → M Exp
  goExp env = \case
    Function params body → do
      (bodyEnv, params') ← bindParams env params
      (_, body') ← goBlock bodyEnv body
      pure (Function params' body')
    Var v → Var <$> goVar env v
    TableCtor rows → TableCtor <$> traverse (traverse (goRow env)) rows
    UnOp op e → UnOp op <$> goExpA env e
    BinOp op a b → BinOp op <$> goExpA env a <*> goExpA env b
    FunctionCall f args →
      FunctionCall <$> goExpA env f <*> traverse (goExpA env) args
    MethodCall obj n args →
      MethodCall <$> goExpA env obj <*> pure n <*> traverse (goExpA env) args
    Paren e → Paren <$> goExpA env e
    atom → pure atom

  goRow ∷ Env → TableRowF Comments → M (TableRowF Comments)
  goRow env = \case
    TableRowKV k v → TableRowKV <$> goExpA env k <*> goExpA env v
    TableRowNV n v → TableRowNV n <$> goExpA env v
    TableRowV v → TableRowV <$> goExpA env v

  goVar ∷ Env → Annotated Comments VarF → M (Annotated Comments VarF)
  goVar env (c, v) =
    (c,) <$> case v of
      VarName n → pure (VarName (Map.findWithDefault n n env))
      VarIndex e1 e2 → VarIndex <$> goExpA env e1 <*> goExpA env e2
      VarField e n → (`VarField` n) <$> goExpA env e

  bindName ∷ Env → Name → M (Env, Name)
  bindName env n =
    case renumberedText (Delimiter "_S_") (`Set.member` free) (Name.toText n) of
      Nothing → pure (env, n)
      Just mintText → do
        n' ← Name.unsafeName <$> mintText
        pure (Map.insert n n' env, n')

  bindNames ∷ Env → NonEmpty Name → M (Env, NonEmpty Name)
  bindNames env (n :| ns) = do
    (env1, n') ← bindName env n
    (env2, ns') ← bindList env1 ns
    pure (env2, n' :| ns')
   where
    bindList e = \case
      [] → pure (e, [])
      x : xs → do
        (e1, x') ← bindName e x
        (e2, xs') ← bindList e1 xs
        pure (e2, x' : xs')

  bindParams
    ∷ Env
    → [Annotated Comments ParamF]
    → M (Env, [Annotated Comments ParamF])
  bindParams env = \case
    [] → pure (env, [])
    (c, param) : rest → do
      (env', param') ← case param of
        ParamNamed n → second ParamNamed <$> bindName env n
        other → pure (env, other)
      (envFinal, rest') ← bindParams env' rest
      pure (envFinal, (c, param') : rest')

--------------------------------------------------------------------------------
-- Free variables --------------------------------------------------------------

{- | The names read or written as variables without a binding local
declaration in scope — the chunk's global accesses (an FFI file's stdlib
or host-API reads). Renumbering must never produce one of these
spellings, or the renamed binder would capture the global reference.
-}
freeVarNames ∷ Chunk → Set Text
freeVarNames chunk = fst (goStats mempty chunk)
 where
  goStats ∷ Set Name → [StatementF Comments] → (Set Text, Set Name)
  goStats bound = \case
    [] → (mempty, bound)
    s : rest →
      let (frees, bound') = goStat bound s
          (frees', boundFinal) = goStats bound' rest
       in (frees <> frees', boundFinal)

  goBlock ∷ Set Name → [Annotated Comments StatementF] → (Set Text, Set Name)
  goBlock bound = goStats bound . fmap snd

  goStat ∷ Set Name → StatementF Comments → (Set Text, Set Name)
  goStat bound = \case
    Local names values →
      ( foldMap (goExpA bound) values
      , bound <> Set.fromList (toList names)
      )
    LocalFunction fname params body →
      let bound' = Set.insert fname bound
       in (fst (goBlock (bound' <> paramNames params) body), bound')
    Assign vars vals →
      (foldMap (goVar bound) vars <> foldMap (goExpA bound) vals, bound)
    IfThenElse p tb eb →
      ( goExpA bound p <> fst (goBlock bound tb) <> fst (goBlock bound eb)
      , bound
      )
    Return es → (foldMap (goExpA bound) es, bound)
    CallStatement e → (goExpA bound e, bound)
    Do body → (fst (goBlock bound body), bound)
    While p body → (goExpA bound p <> fst (goBlock bound body), bound)
    Repeat body p →
      -- The until-condition is in scope of the body's locals.
      let (frees, bound') = goBlock bound body
       in (frees <> goExpA bound' p, bound)
    ForNum n start limit step body →
      ( goExpA bound start
          <> goExpA bound limit
          <> foldMap (goExpA bound) step
          <> fst (goBlock (Set.insert n bound) body)
      , bound
      )
    ForIn names es body →
      ( foldMap (goExpA bound) es
          <> fst (goBlock (bound <> Set.fromList (toList names)) body)
      , bound
      )
    Break → (mempty, bound)

  goExpA ∷ Set Name → Annotated Comments ExpF → Set Text
  goExpA bound = goExp bound . snd

  goExp ∷ Set Name → ExpF Comments → Set Text
  goExp bound = \case
    Function params body → fst (goBlock (bound <> paramNames params) body)
    Var v → goVar bound v
    TableCtor rows →
      flip foldMap rows \(_c, row) → case row of
        TableRowKV k v → goExpA bound k <> goExpA bound v
        TableRowNV _n v → goExpA bound v
        TableRowV v → goExpA bound v
    UnOp _op e → goExpA bound e
    BinOp _op a b → goExpA bound a <> goExpA bound b
    FunctionCall f args → goExpA bound f <> foldMap (goExpA bound) args
    MethodCall obj _n args → goExpA bound obj <> foldMap (goExpA bound) args
    Paren e → goExpA bound e
    Nil → mempty
    Boolean _ → mempty
    Integer _ → mempty
    Float _ → mempty
    String _ → mempty
    Vararg → mempty

  goVar ∷ Set Name → Annotated Comments VarF → Set Text
  goVar bound (_c, v) = case v of
    VarName n
      | Set.member n bound → mempty
      | otherwise → Set.singleton (Name.toText n)
    VarIndex e1 e2 → goExpA bound e1 <> goExpA bound e2
    VarField e _n → goExpA bound e

  paramNames ∷ [Annotated Comments ParamF] → Set Name
  paramNames anns = Set.fromList [n | (_c, ParamNamed n) ← anns]
