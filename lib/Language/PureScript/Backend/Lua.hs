module Language.PureScript.Backend.Lua
  ( fromUberModule
  , fromIR
  , fromName
  , qualifyName
  , Error (..)
  ) where

import Control.Arrow (left)
import Control.Monad.Oops (CouldBe, Variant)
import Control.Monad.Oops qualified as Oops
import Control.Monad.Trans.Accum (AccumT, add, runAccumT)
import Data.DList qualified as DList
import Data.IntCast (intCast)
import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Set qualified as Set
import Data.Tagged (Tagged (..), untag)
import Data.Text qualified as Text
import Data.Traversable (for)
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linker qualified as Linker
import Language.PureScript.Backend.IR.Query (usesRuntimeLazy)
import Language.PureScript.Backend.Lua.Fixture qualified as Fixture
import Language.PureScript.Backend.Lua.Key qualified as Key
import Language.PureScript.Backend.Lua.Linker.Foreign qualified as Foreign
import Language.PureScript.Backend.Lua.Loopify qualified as Loopify
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.NativeLoop qualified as NativeLoop
import Language.PureScript.Backend.Lua.RefUnbox qualified as RefUnbox
import Language.PureScript.Backend.Lua.Types (ParamF (..))
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Language.PureScript.Backend.Types (AppOrModule (..))
import Language.PureScript.Names (ModuleName (..), runModuleName)
import Language.PureScript.Names qualified as PS
import Language.PureScript.PSString (decodeStringEscaping, mkString)
import Path (Abs, Dir, Path)
import Prelude hiding (exp, local)

type LuaM e a =
  AccumT UsesObjectUpdate (StateT Natural (ExceptT (Variant e) IO)) a

data UsesObjectUpdate = NoObjectUpdate | UsesObjectUpdate
  deriving stock (Eq, Ord, Show)

instance Semigroup UsesObjectUpdate where
  _ <> UsesObjectUpdate = UsesObjectUpdate
  UsesObjectUpdate <> _ = UsesObjectUpdate
  NoObjectUpdate <> NoObjectUpdate = NoObjectUpdate

instance Monoid UsesObjectUpdate where
  mempty = NoObjectUpdate

data Error
  = LinkerErrorForeign Foreign.Error
  | {- | Names declared as @foreign import@s whose keys are missing from the
    table the module's FFI file returns. Every such read would be @nil@ at
    runtime, so lowering rejects the module instead. See issue #249.
    -}
    ForeignExportsMissing ModuleName (NonEmpty IR.Name)
  | AppEntryPointNotFound ModuleName PS.Ident
  | {- | The generated chunk nests more deeply than Lua 5.1's parser allows
    (~200 syntax levels), so it would fail to load. Carries the measured
    depth. See 'Language.PureScript.Backend.Lua.NestingCheck' and issue #104.
    -}
    NestingTooDeep Int
  deriving stock (Show)

fromUberModule
  ∷ ∀ e
   . e `CouldBe` Error
  ⇒ Tagged "foreign" (Path Abs Dir)
  → Tagged "needsRuntimeLazy" Bool
  → AppOrModule
  → Linker.UberModule
  → ExceptT (Variant e) IO Lua.Chunk
fromUberModule foreigns needsRuntimeLazy appOrModule uber = (`evalStateT` 0) do
  ((bindings, returnStat), usesObjectUpdate) ← (`runAccumT` NoObjectUpdate) do
    foreignBindings ←
      forM (Linker.uberModuleForeigns uber) \(IR.QName modname name, irExp) → do
        exp ← asExpression <$> fromIR foreigns Set.empty Set.empty modname irExp
        pure $ mkBinding modname (fromName name) exp

    bindings ←
      Linker.uberModuleBindings uber & foldMapM \case
        IR.Standalone (IR.QName modname name, irExp) → do
          exp ← fromIR foreigns Set.empty Set.empty modname irExp
          pure . DList.singleton $
            mkBinding modname (fromName name) (asExpression exp)
        IR.RecursiveGroup recGroup → do
          recBinds ← forM (toList recGroup) \(IR.QName modname name, irExp) →
            (modname,name,) . asExpression
              <$> fromIR foreigns Set.empty Set.empty modname irExp
          -- A recursive member references itself (and its siblings)
          -- through the module-scope table, mirroring the Ref case of
          -- 'fromIR'.
          let memberSelf modname name =
                Loopify.SelfField
                  Fixture.moduleName
                  (qualifyName modname (fromName name))
          -- The members of every mutual tail-call cycle lower to one
          -- while-true dispatcher plus entry wrappers (issue #234); see
          -- Language.PureScript.Backend.Lua.Loopify.
          dispatched ←
            forM
              ( Loopify.planGroupDispatch
                  [ (memberSelf modname name, exp)
                  | (modname, name, exp) ← recBinds
                  ]
              )
              \dispatchGroup → do
                selector ← freshName "$sel"
                slots ←
                  replicateM (Loopify.dispatchArity dispatchGroup) (freshName "$a")
                let leader = NE.head (Loopify.dispatchMembers dispatchGroup)
                    -- The leader's Self already carries the qualified
                    -- module-scope field, so the dispatcher derives its
                    -- name from it directly.
                    dispatcherName =
                      Name.makeSafe $
                        Name.toText (Loopify.selfName (Loopify.dispatchSelf leader))
                          <> "$loop"
                    dispatcherSelf =
                      Loopify.SelfField Fixture.moduleName dispatcherName
                    (dispatcherExp, wrappers) =
                      Loopify.emitDispatchGroup
                        dispatcherSelf
                        selector
                        slots
                        dispatchGroup
                pure ((dispatcherName, dispatcherExp), wrappers)
          let wrapperByIndex = concatMap snd dispatched
          pure $
            DList.fromList
              [ Lua.assign
                  ( Lua.VarField
                      (Lua.ann (Lua.varName Fixture.moduleName))
                      dispatcherName
                  )
                  dispatcherExp
              | ((dispatcherName, dispatcherExp), _) ← dispatched
              ]
              <> DList.fromList do
                (index, (modname, name, exp)) ← zip [0 ..] recBinds
                let luaExp = case List.lookup index wrapperByIndex of
                      Just wrapper → wrapper
                      Nothing → Loopify.loopify (memberSelf modname name) exp
                pure $ mkBinding modname (fromName name) luaExp

    returnExp ←
      case appOrModule of
        AsModule modname →
          Lua.table <$> forM (uberModuleExports uber) \(fromName → name, expr) →
            Lua.tableRowNV name . asExpression
              <$> fromIR foreigns Set.empty mempty modname expr
        AsApplication modname ident → do
          case List.lookup name (uberModuleExports uber) of
            Just expr → do
              entry ← fromIR foreigns Set.empty mempty modname expr
              pure $ Lua.functionCall (asExpression entry) []
            _ → Oops.throw $ AppEntryPointNotFound modname ident
         where
          name = IR.identToName ident

    pure
      ( DList.fromList foreignBindings <> bindings
      , Lua.Return [Lua.ann returnExp]
      )

  pure . mconcat $
    -- See Note [The PSLUA_runtime_lazy coupling] in Language.PureScript.Names
    [ [Fixture.runtimeLazy | untag needsRuntimeLazy && usesRuntimeLazy uber]
    , [Fixture.objectUpdate | UsesObjectUpdate ← [usesObjectUpdate]]
    , [Lua.local1 Fixture.moduleName (Lua.table []) | not (null bindings)]
    , toList (DList.snoc bindings returnStat)
    ]

mkBinding ∷ ModuleName → Lua.Name → Lua.Exp → Lua.Statement
mkBinding modname name =
  Lua.assign $
    Lua.VarField
      (Lua.ann (Lua.varName Fixture.moduleName))
      (qualifyName modname name)

-- Chunks are finalized here and in the 'IR.AbsN' case of 'fromIR', so
-- both fuse the chunk's join points first (issue #234); see
-- Language.PureScript.Backend.Lua.Loopify.
asExpression ∷ Either Lua.Chunk Lua.Exp → Lua.Exp
asExpression = \case
  Left chunk → Lua.chunkToExpression (Loopify.joinifyChunk chunk)
  Right expr → expr

fromName ∷ HasCallStack ⇒ IR.Name → Lua.Name
fromName = Name.makeSafe . IR.nameToText

fromModuleName ∷ ModuleName → Lua.Name
fromModuleName = Name.makeSafe . runModuleName

fromPropName ∷ IR.PropName → Lua.Name
fromPropName (IR.PropName name) = Name.makeSafe name

{- Note [Nullary functions and Prim.undefined]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'ParamUnused' compiles to a zero-parameter Lua function and a 'Prim.undefined'
argument compiles to a zero-argument call. These two arity-changing encodings
are halves of one convention and must stay in sync. PureScript emits a thunk as
@(\_unused -> body) Prim.undefined@, which 'fromIR' lowers to
@(function() body end)()@: zero parameters, called with zero arguments. If only
one side elided, the generated function and its call sites would disagree on
arity. The Lua printer likewise drops 'ParamUnused' from the parameter list
(Language.PureScript.Backend.Lua.Printer).
-}
fromIR
  ∷ ∀ e
   . e `CouldBe` Error
  ⇒ Tagged "foreign" (Path Abs Dir)
  → Set IR.Name
  {- ^ Cells lowered to mutable locals, in scope for this expression
  ("Language.PureScript.Backend.Lua.RefUnbox").
  -}
  → Set Lua.Name
  → ModuleName
  → IR.Exp
  → LuaM e (Either Lua.Chunk Lua.Exp)
fromIR foreigns unboxed topLevelNames modname ir = case ir of
  IR.LiteralInt _ann i →
    pure . Right $ Lua.Integer i
  IR.LiteralFloat _ann d →
    pure . Right $ Lua.Float d
  IR.LiteralString _ann s →
    pure . Right $ Lua.String s
  IR.LiteralChar _ann c →
    -- See Note [PSString is UTF-16 code units, not text]
    pure (Right (Lua.String (decodeStringEscaping (mkString (Text.singleton c)))))
  IR.LiteralBool _ann b →
    pure . Right $ Lua.Boolean b
  IR.LiteralArray _ann exprs →
    Right . Lua.table <$> forM (zip [1 ..] exprs) \(i, e) →
      Lua.tableRowKV (Lua.Integer i) <$> goExp e
  IR.LiteralObject _ann kvs →
    Right . Lua.table <$> for kvs \(prop, exp) →
      Lua.tableRowNV (fromPropName prop) <$> goExp exp
  IR.ReflectCtor _ann e →
    Right . (`Lua.varIndex` Lua.Integer 1) <$> goExp e
  IR.DataArgumentByIndex _ann algTy i e →
    -- Constructor fields sit in consecutive array slots after the tag
    -- (sum types) or from slot 1 (product types, which carry no tag) —
    -- see the 'IR.Ctor' case below.
    Right . (`Lua.varIndex` Lua.Integer (intCast i + offset)) <$> goExp e
   where
    offset = case algTy of
      IR.SumType → 2
      IR.ProductType → 1
  IR.Eq _ann l r →
    Right <$> liftA2 Lua.equalTo (goExp l) (goExp r)
  -- See Note [IR primops]: lowering is the identity onto the Lua operator.
  IR.PrimBinOp _ann op l r →
    Right <$> liftA2 (Lua.binOp (luaBinaryOp op)) (goExp l) (goExp r)
  IR.PrimNot _ann e →
    Right . Lua.logicalNot <$> goExp e
  IR.Ctor _ann algebraicTy ctorModName ctorTyName ctorName ctorArgs →
    -- A constructor value is a positional table built directly from the
    -- compiled field arguments (the node is saturated by construction — see
    -- Note [Constructor applications are saturated]). The tag string sits in
    -- slot 1 and fields in the slots after it for a sum type; a product
    -- value omits the tag row, so its fields start at slot 1. Only sum-type
    -- constructors need the tag: the pattern matcher emits a ReflectCtor read
    -- (the reflectCtor == ctorId test) exclusively for sum types, so on a
    -- product value the row would never be read. See Note [Compiling case
    -- expressions to decision trees].
    --
    -- The rows stay positional ('TableRowV'), not '[i] = v' keyed
    -- ('TableRowKV'): only a positional constructor pre-sizes the table's
    -- array part in PUC Lua 5.1 — keyed integer rows go through the hash
    -- lookup this representation exists to avoid. A positional row carrying a
    -- multi-valued expression (a call or '...') would splice its extra
    -- results into the table, but Lua adjusts every non-final positional
    -- element to one value, so only the final field needs the explicit-parens
    -- guard 'parenLastMultiValued' applies.
    Right . Lua.table . rows <$> traverse goExp ctorArgs
   where
    rows compiledArgs = case algebraicTy of
      IR.SumType → ctorRow : fieldRows compiledArgs
      IR.ProductType → fieldRows compiledArgs
    fieldRows = fmap Lua.tableRowV . parenLastMultiValued
    ctorId = IR.ctorId ctorModName ctorTyName ctorName
    ctorRow = Lua.tableRowV (Lua.String ctorId)
  IR.ArrayLength _ann e →
    Right . Lua.hash <$> goExp e
  IR.ArrayIndex _ann expr index →
    -- IR array indices are 0-based (like the source language), but Lua
    -- tables are 1-based, so shift by one. This mirrors the arrays FFI
    -- `indexImpl`, which reads `xs[i + 1]`. See issue #49.
    Right . flip Lua.varIndex (Lua.Integer (intCast index + 1)) <$> goExp expr
  IR.ObjectProp _ann expr propName →
    Right . flip Lua.varField (fromPropName propName) <$> goExp expr
  IR.ObjectUpdate _ann expr propValues → do
    add UsesObjectUpdate
    obj ← goExp expr
    vals ←
      Lua.table <$> for (toList propValues) \(propName, e) →
        Lua.tableRowNV (fromPropName propName) <$> goExp e
    pure . Right $
      Lua.functionCall (Lua.varName Fixture.objectUpdateName) [obj, vals]
  -- See Note [Nullary functions and Prim.undefined]
  IR.AbsN _ann params expr → do
    body ← go expr
    let luaParams =
          -- The trailing run of unused parameters is dropped; a
          -- non-trailing 'ParamUnused' cannot occur
          -- (Note [n-ary abstraction] in ...Backend.IR.Types).
          [ ParamNamed (fromName name)
          | IR.ParamNamed _pann name ←
              List.dropWhileEnd isUnusedParam (toList params)
          ]
    pure . Right $ case body of
      Left chunk → Lua.functionDef luaParams (Loopify.joinifyChunk chunk)
      Right e → Lua.functionDef luaParams [Lua.return e]
  -- Running the literal thunk that a saturated lifted @*.Uncurried@ effect
  -- wrapper reduces to — @(\_ -> fn(a, …)) EffectRunArg@ — is just the call
  -- @fn(a, …)@: the uncurried @fn@ runs once it has every argument, so no
  -- thunk need be built and immediately forced (issue #198). This is the
  -- effect-side payoff of the lift — @fn(a, …)@ instead of
  -- @(function() return fn(a, …) end)()@. The 'IR.EffectRunArg' marker is
  -- kept in the IR through the pipeline, so dead-code elimination still keeps
  -- the (result-unused) effect statement (see 'IR.isEffectRun'); only codegen
  -- drops the redundant force. The body is required to be an 'IR.AppN', which
  -- always lowers to an expression — so this never inlines a 'Let' (magic-do
  -- keeps such chunk boundaries thunked to bound locals per Lua function).
  IR.AppN
    _ann
    (IR.AbsN _ (IR.ParamUnused _ :| []) body@IR.AppN {})
    (IR.EffectRunArg _ :| []) →
      Right <$> goExp body
  -- The run of a saturated Effect/ST loop-combinator application lowers
  -- to the native Lua loop instead of the foreign call (issue #233); see
  -- Language.PureScript.Backend.Lua.NativeLoop. The chunk carries no
  -- 'Lua.Return' — the run yields no values, exactly like the foreign
  -- thunk falling off its end — so every consumer of a 'Left' chunk
  -- (spliced statements, a scope-call expression) preserves semantics.
  loopRun@IR.AppN {}
    | Just loop ← NativeLoop.matchLoopRun loopRun →
        Left <$> NativeLoop.lowerLoop go freshName loop
  -- The run of a recognised operation on an unboxed cell (issue #239);
  -- see Language.PureScript.Backend.Lua.RefUnbox. A read is a plain
  -- expression (the local itself); a mutating run lowers to a chunk
  -- ending in a return of the run's value — spliced when it sits in a
  -- tail, wrapped in a scope call otherwise (the cell then mutates
  -- through the closure's upvalue, which is the same slot).
  opRun@IR.AppN {}
    | Just (cell, use) ← RefUnbox.matchOpRun opRun
    , Set.member cell unboxed → do
        (stmts, value) ← RefUnbox.lowerOpRun goExp freshName (fromName cell) use
        pure case stmts of
          [] → Right value
          _ → Left (stmts <> [Lua.return value])
  IR.AppN _ann fn args → do
    e ← goExp fn
    -- See Note [Nullary functions and Prim.undefined]. PS inserts a
    -- synthetic unused argument "Prim.undefined" to force a thunk (and
    -- magic-do inserts its 'IR.EffectRunArg' twin to run one). The
    -- trailing run of such arguments is elided (the nullary call
    -- included, so it is emitted as f() rather than f(nil)), mirroring
    -- the dropped trailing run of unused parameters above. A
    -- non-trailing one can only face an unused (named-dummy) parameter
    -- of an uncurried worker, so it lowers to an explicit nil.
    let keptArgs = List.dropWhileEnd isErasedThunkArg (toList args)
    Right . Lua.functionCall e <$> for keptArgs \arg →
      if isErasedThunkArg arg then pure Lua.Nil else goExp arg
  IR.Ref _ann qualifiedName →
    case qualifiedName of
      IR.Local name
        | topLevelName ← qualifyName modname (fromName name)
        , Set.member topLevelName topLevelNames →
            pure . Right $
              Lua.varField (Lua.varName Fixture.moduleName) topLevelName
      -- A local name is unique within its top-level site (GUC,
      -- established by 'Language.PureScript.Backend.IR.Uniquify'), so
      -- it renders as a plain Lua variable.
      IR.Local name → pure . Right $ Lua.varName (fromName name)
      IR.Imported modname' name →
        pure . Right $
          Lua.varField
            (Lua.varName Fixture.moduleName)
            (qualifyName modname' (fromName name))
  -- Standalone bindings become a sequence of 'local' statements, which
  -- matches Note [Sequential scoping of Let bindings]. The bindings are
  -- processed left to right carrying the set of cells unboxed so far
  -- (issue #239): a binding may extend it, and everything after —
  -- including the body — compiles under the extended set.
  IR.Let _ann bindings bodyExp → do
    (recs, unboxed') ← goBindings unboxed (toList bindings)
    body ← fromIR foreigns unboxed' topLevelNames modname bodyExp
    pure . Left . DList.toList $
      recs <> either DList.fromList (DList.singleton . Lua.return) body
   where
    goWith env = fromIR foreigns env topLevelNames modname
    goExpWith env = asExpression <<$>> goWith env

    goBindings
      ∷ Set IR.Name
      → [IR.Grouping (IR.Ann, IR.Name, IR.Exp)]
      → LuaM e (DList.DList Lua.Statement, Set IR.Name)
    goBindings env = \case
      [] → pure (mempty, env)
      grouping : rest → do
        (stmts, env') ← goGrouping env grouping rest
        first (stmts <>) <$> goBindings env' rest

    goGrouping
      ∷ Set IR.Name
      → IR.Grouping (IR.Ann, IR.Name, IR.Exp)
      → [IR.Grouping (IR.Ann, IR.Name, IR.Exp)]
      → LuaM e (DList.DList Lua.Statement, Set IR.Name)
    goGrouping env grouping rest = case grouping of
      -- A cell allocation whose every use in the remaining scope goes
      -- through the recognised operations unboxes: the binder holds the
      -- initial value directly, and the uses lower against it (issue
      -- #239); see Language.PureScript.Backend.Lua.RefUnbox.
      IR.Standalone (_bindAnn, name, expr)
        | name /= IR.discardName
        , Just initial ← RefUnbox.matchNewRun expr
        , RefUnbox.usedOnlyThroughOps
            name
            (concatMap (fmap (\(_, _, e) → e) . IR.listGrouping) rest <> [bodyExp]) → do
            initExp ← goExpWith env initial
            pure
              ( DList.singleton (Lua.local1 (fromName name) initExp)
              , Set.insert name env
              )
        -- A statement whose RHS runs a recognised operation on an
        -- unboxed cell lowers to the operation's statements, the binder
        -- receiving the run's value.
        | Just (cell, use) ← RefUnbox.matchOpRun expr
        , Set.member cell env → do
            stmts ←
              RefUnbox.lowerOpRunBinding
                (goExpWith env)
                freshName
                ( if name == IR.discardName
                    then Nothing
                    else Just (fromName name)
                )
                (fromName cell)
                use
            pure (DList.fromList stmts, env)
        -- A statement whose RHS is a recognised loop run emits the
        -- native loop directly instead of `local x = <scope call>`. The
        -- run yields no values, so the binder reads nil either way:
        -- `local x` declares exactly that, and the discard binder — never
        -- referenced (the 'RefToDiscard' lint pins this) — needs no
        -- declaration at all.
        | Just loop ← NativeLoop.matchLoopRun expr → do
            loopStmts ← NativeLoop.lowerLoop (goWith env) freshName loop
            pure
              ( DList.fromList loopStmts
                  <> if name == IR.discardName
                    then mempty
                    else DList.singleton (Lua.local0 (fromName name))
              , env
              )
      IR.Standalone (_bindAnn, name, expr) → do
        luaExp ← goExpWith env expr
        pure (DList.singleton (Lua.local1 (fromName name) luaExp), env)
      IR.RecursiveGroup grp → do
        compiled ← forM (toList grp) \(_bindAnn, name, expr) → do
          luaExp ← goExpWith env expr
          -- The self-reference mirrors the Ref case below: through the
          -- module-scope table for a top-level name, plain otherwise.
          let luaName = fromName name
              (target, self)
                | Set.member (qualifyName modname luaName) topLevelNames =
                    ( qualifyName modname luaName
                    , Loopify.SelfField
                        Fixture.moduleName
                        (qualifyName modname luaName)
                    )
                | otherwise = (luaName, Loopify.SelfLocal luaName)
          pure (name, target, self, luaExp)
        -- The members of every mutual tail-call cycle dispatch through
        -- a shared local (issue #234), mirroring the top-level case in
        -- 'fromUberModule'.
        dispatched ←
          forM
            ( Loopify.planGroupDispatch
                [(self, luaExp) | (_, _, self, luaExp) ← compiled]
            )
            \dispatchGroup → do
              selector ← freshName "$sel"
              slots ←
                replicateM (Loopify.dispatchArity dispatchGroup) (freshName "$a")
              let leader = NE.head (Loopify.dispatchMembers dispatchGroup)
                  dispatcherName =
                    Name.makeSafe $
                      Name.toText (Loopify.selfName (Loopify.dispatchSelf leader))
                        <> "$loop"
                  (dispatcherExp, wrappers) =
                    Loopify.emitDispatchGroup
                      (Loopify.SelfLocal dispatcherName)
                      selector
                      slots
                      dispatchGroup
              pure ((dispatcherName, dispatcherExp), wrappers)
        let wrapperByIndex = concatMap snd dispatched
            binds =
              [ Lua.local0 dispatcherName
              | ((dispatcherName, _), _) ← dispatched
              ]
                <> [Lua.local0 target | (_, target, _, _) ← compiled]
            assignments =
              [ Lua.assign (Lua.VarName dispatcherName) dispatcherExp
              | ((dispatcherName, dispatcherExp), _) ← dispatched
              ]
                <> [ Lua.assign (Lua.VarName target) luaExp'
                   | (index, (_, target, self, luaExp)) ←
                       zip [0 ..] compiled
                   , let luaExp' = case List.lookup index wrapperByIndex of
                           Just wrapper → wrapper
                           Nothing → Loopify.loopify self luaExp
                   ]
        pure (DList.fromList binds <> DList.fromList assignments, env)
  -- A multi-value return: only reachable in a multi-value tail position
  -- (Note [Multi-value results] in ...Backend.IR.Types), so it lowers to
  -- the final @return e₁, …, eₙ@ of the enclosing chunk. Each element is
  -- a single-value slot: a multi-valued call in the last slot would
  -- splice its extra results into the return list, so it gets the same
  -- explicit-parens guard as the last field of a constructor.
  IR.Values _ann exprs → do
    es ← traverse goExp (toList exprs)
    pure . Left $ [Lua.returnN (NE.fromList (parenLastMultiValued es))]
  -- @local p₁, …, pₙ = rhs@ followed by the body statements. The
  -- trailing run of unused binders is dropped — Lua discards surplus
  -- results — and a non-trailing 'IR.ParamUnused' cannot occur
  -- (Note [Multi-value results]). The RHS is never paren-wrapped: it is
  -- the multi-valued producer whose results the binder list captures.
  IR.LetValues _ann params rhs bodyExp → do
    rhsExp ← goExp rhs
    body ← go bodyExp
    let binding = case nonEmpty keptNames of
          Just names → Lua.localN names rhsExp
          -- Every binder is unused (an all-dead suffix DCE has not
          -- collapsed yet): keep the RHS evaluation, discard the values.
          Nothing → Lua.local1 (fromName (IR.Name "_")) rhsExp
        keptNames =
          [ fromName name
          | IR.ParamNamed _pann name ←
              List.dropWhileEnd isUnusedParam (toList params)
          ]
    pure . Left $ binding : either id (pure . Lua.return) body
  IR.IfThenElse _ann cond th el → do
    thenExp ← go th
    elseExp ← go el
    condExp ← goExp cond
    let
      thenBranch = either id (pure . Lua.return) thenExp
      elseBranch = either id (pure . Lua.return) elseExp
    pure $ Left [Lua.ifThenElse condExp thenBranch elseBranch]
  IR.Exception _ann msg →
    pure . Right $ Lua.error msg
  IR.ForeignImport _ann foreignModuleName path annotatedNames → do
    let foreignNames = fromName <<$>> annotatedNames
    -- See Note [Foreign module source format] in ...Lua.Linker.Foreign
    Foreign.Source {header, returnComments, exports} ←
      Oops.hoistEither =<< liftIO do
        left LinkerErrorForeign
          <$> Foreign.parseForeignSource (untag foreigns) path
    -- A declared name absent from the FFI exports would lower to a read of
    -- a missing table field and fail only at runtime, as a nil. The carried
    -- name list is DCE-pruned, so exactly the names the emitted accessors
    -- will read are required to exist.
    let exportedNames =
          Set.fromList [Key.toSafeName key | (key, _value) ← toList exports]
    whenJust
      ( nonEmpty
          [ name
          | (_nameAnn, name) ← annotatedNames
          , fromName name `Set.notMember` exportedNames
          ]
      )
      (Oops.throw . ForeignExportsMissing foreignModuleName)
    let keptRows =
          [ (comments, Lua.TableRowNV name (Lua.ann value))
          | (key, (comments, value)) ← toList exports
          , -- See Note [Lua reserved words as foreign export keys]
          -- Export tables can contain Lua-reserved words as keys, for
          -- example `{ ["for"] = 42 }`; toSafeName mangles them.
          let name = Key.toSafeName key
          , name `elem` fmap snd foreignNames
          ]
        -- Comments preceding the exports return (e.g. the module-level
        -- commentary of a header-less FFI file) stay with the first kept row.
        foreignExports = Lua.TableCtor case keptRows of
          (comments, row) : rest → (returnComments <> comments, row) : rest
          [] → []
    pure case header of
      [] → Right foreignExports
      stats →
        -- The parsed header statements keep their comment annotations, so
        -- they are embedded directly rather than re-annotated via smart
        -- constructors.
        Right . Lua.FunctionCall (Lua.ann (Lua.Function [] scopeBody)) $ []
       where
        scopeBody = stats <> [Lua.ann (Lua.Return [Lua.ann foreignExports])]
 where
  go ∷ IR.Exp → LuaM e (Either Lua.Chunk Lua.Exp)
  go = fromIR foreigns unboxed topLevelNames modname

  goExp ∷ IR.Exp → LuaM e Lua.Exp
  goExp = asExpression <<$>> go

{- | Mint a codegen-fresh local name: the prefix plus a counter drawn
from the 'LuaM' supply, mangled by 'Name.makeSafe' (@$i0@ → @_S_i0@).
The prefix must start with @$@ — unreachable from PureScript
identifiers, and none of the IR passes' @$@-prefixed supplies mint
these prefixes — so the name cannot capture or be captured.
-}
freshName ∷ Text → LuaM e Lua.Name
freshName prefix = lift $ state \n → (Name.makeSafe (prefix <> show n), n + 1)

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

-- | The Lua binary operator each 'IR.PrimBinOp' lowers to. See Note [IR primops].
luaBinaryOp ∷ IR.PrimOp → Lua.BinaryOp
luaBinaryOp = \case
  IR.PrimAdd → Lua.Add
  IR.PrimSub → Lua.Sub
  IR.PrimMul → Lua.Mul
  IR.PrimDiv → Lua.FloatDiv
  IR.PrimMod → Lua.Mod
  IR.PrimConcat → Lua.Concat
  IR.PrimLt → Lua.LessThan
  IR.PrimLe → Lua.LessThanOrEqualTo
  IR.PrimGt → Lua.GreaterThan
  IR.PrimGe → Lua.GreaterThanOrEqualTo
  IR.PrimAnd → Lua.And
  IR.PrimOr → Lua.Or

qualifyName ∷ ModuleName → Lua.Name → Lua.Name
qualifyName modname = Name.join2 (fromModuleName modname)

{- | Guard the final element of a constructor's positional field list against
splicing. A multi-valued Lua expression — a function call, a method call, or
@...@ — in the last array slot of a table constructor expands to all its
results, growing the constructor with extra fields. Wrapping it in explicit
parens ('Lua.Paren') adjusts it back to exactly one value. Only the last
element needs this: Lua adjusts every non-final positional element to one
value on its own.
-}
parenLastMultiValued ∷ [Lua.Exp] → [Lua.Exp]
parenLastMultiValued = \case
  [] → []
  [x] → [parenMultiValued x]
  (x : xs) → x : parenLastMultiValued xs

parenMultiValued ∷ Lua.Exp → Lua.Exp
parenMultiValued e = case e of
  Lua.FunctionCall {} → Lua.Paren (Lua.ann e)
  Lua.MethodCall {} → Lua.Paren (Lua.ann e)
  Lua.Vararg → Lua.Paren (Lua.ann e)
  _ → e

isUnusedParam ∷ IR.Parameter ann → Bool
isUnusedParam = isNothing . IR.paramName

{- | A synthetic argument the Lua backend erases to a zero-argument call: the
@Prim.undefined@ PureScript passes to force a nullary thunk, or magic-do's
'IR.EffectRunArg' effect-run marker. Both are ignored by the receiving thunk.
-}
isErasedThunkArg ∷ IR.Exp → Bool
isErasedThunkArg = \case
  IR.Ref _ann (IR.Imported (IR.ModuleName "Prim") (IR.Name "undefined")) →
    True
  IR.EffectRunArg _ →
    True
  _ → False
