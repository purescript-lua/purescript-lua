module Language.PureScript.Backend.Lua
  ( fromUberModule
  , fromIR
  , fromName
  , qualifyName
  , Error (..)
  ) where

import Control.Arrow (left)
import Control.Monad (ap)
import Control.Monad.Oops (CouldBe, Variant)
import Control.Monad.Oops qualified as Oops
import Control.Monad.Trans.Accum (AccumT, add, runAccumT)
import Data.DList qualified as DList
import Data.IntCast (intCast)
import Data.List qualified as List
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
        exp ← asExpression <$> fromIR foreigns Set.empty modname irExp
        pure $ mkBinding modname (fromName name) exp

    bindings ←
      Linker.uberModuleBindings uber & foldMapM \case
        IR.Standalone (IR.QName modname name, irExp) → do
          exp ← fromIR foreigns Set.empty modname irExp
          pure . DList.singleton $
            mkBinding modname (fromName name) (asExpression exp)
        IR.RecursiveGroup recGroup → do
          recBinds ← forM (toList recGroup) \(IR.QName modname name, irExp) →
            (modname,name,) . asExpression
              <$> fromIR foreigns Set.empty modname irExp
          pure $ DList.fromList do
            (modname, name, exp) ← recBinds
            -- A self-recursive member references itself through the
            -- module-scope table, mirroring the Ref case of 'fromIR'.
            let self =
                  Loopify.SelfField
                    Fixture.moduleName
                    (qualifyName modname (fromName name))
            pure $ mkBinding modname (fromName name) (Loopify.loopify self exp)

    returnExp ←
      case appOrModule of
        AsModule modname →
          Lua.table <$> forM (uberModuleExports uber) \(fromName → name, expr) →
            Lua.tableRowNV name . asExpression
              <$> fromIR foreigns mempty modname expr
        AsApplication modname ident → do
          case List.lookup name (uberModuleExports uber) of
            Just expr → do
              entry ← fromIR foreigns mempty modname expr
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

asExpression ∷ Either Lua.Chunk Lua.Exp → Lua.Exp
asExpression = \case
  Left chunk → Lua.chunkToExpression chunk
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
  → Set Lua.Name
  → ModuleName
  → IR.Exp
  → LuaM e (Either Lua.Chunk Lua.Exp)
fromIR foreigns topLevelNames modname ir = case ir of
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
    Right . (`Lua.varIndex` keyCtor) <$> goExp e
  IR.DataArgumentByIndex _ann i e →
    Right . (`Lua.varField` Lua.unsafeName ("value" <> show i)) <$> goExp e
  IR.Eq _ann l r →
    Right <$> liftA2 Lua.equalTo (goExp l) (goExp r)
  -- See Note [IR primops]: lowering is the identity onto the Lua operator.
  IR.PrimBinOp _ann op l r →
    Right <$> liftA2 (Lua.binOp (luaBinaryOp op)) (goExp l) (goExp r)
  IR.PrimNot _ann e →
    Right . Lua.logicalNot <$> goExp e
  IR.Ctor _ann algebraicTy ctorModName ctorTyName ctorName fieldNames →
    pure . Right $ foldr wrap value args
   where
    wrap name expr = Lua.functionDef [ParamNamed name] [Lua.return expr]
    -- Only sum-type constructors need the tag row: the pattern matcher emits a
    -- ReflectCtor read (the reflectCtor == ctorId test) exclusively for sum
    -- types, so on a product value the row would never be read.
    -- See Note [Compiling case expressions to decision trees].
    value = Lua.table case algebraicTy of
      IR.SumType → ctorRow : attributes
      IR.ProductType → attributes
    ctorId = IR.ctorId ctorModName ctorTyName ctorName
    ctorRow = Lua.tableRowKV keyCtor (Lua.String ctorId)
    args = Name.unsafeName . IR.renderFieldName <$> fieldNames
    attributes = args <&> ap Lua.tableRowNV Lua.varName
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
      Left chunk → Lua.functionDef luaParams chunk
      Right e → Lua.functionDef luaParams [Lua.return e]
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
  -- matches Note [Sequential scoping of Let bindings]
  IR.Let _ann bindings bodyExp → do
    body ← go bodyExp
    recs ←
      bindings & foldMapM \case
        IR.Standalone (_ann, name, expr) →
          DList.singleton . Lua.local1 (fromName name) <$> goExp expr
        IR.RecursiveGroup grp → do
          let binds =
                toList grp <&> \(_ann, fromName → name, _) →
                  Lua.local0
                    ( if Set.member (qualifyName modname name) topLevelNames
                        then qualifyName modname name
                        else name
                    )
          assignments ← forM (toList grp) \(_ann, fromName → name, expr) → do
            -- The self-reference mirrors the Ref case below: through the
            -- module-scope table for a top-level name, plain otherwise.
            let (target, self)
                  | Set.member (qualifyName modname name) topLevelNames =
                      ( qualifyName modname name
                      , Loopify.SelfField
                          Fixture.moduleName
                          (qualifyName modname name)
                      )
                  | otherwise = (name, Loopify.SelfLocal name)
            goExp expr
              <&> Lua.assign (Lua.VarName target)
              . Loopify.loopify self
          pure $ DList.fromList binds <> DList.fromList assignments
    pure . Left . DList.toList $
      recs <> either DList.fromList (DList.singleton . Lua.return) body
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
  IR.ForeignImport _ann _moduleName path annotatedNames → do
    let foreignNames = fromName <<$>> annotatedNames
    -- See Note [Foreign module source format] in ...Lua.Linker.Foreign
    Foreign.Source {header, returnComments, exports} ←
      Oops.hoistEither =<< liftIO do
        left LinkerErrorForeign
          <$> Foreign.parseForeignSource (untag foreigns) path
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
  go = fromIR foreigns topLevelNames modname

  goExp ∷ IR.Exp → LuaM e Lua.Exp
  goExp = asExpression <<$>> go

keyCtor ∷ Lua.Exp
keyCtor = Lua.String "$ctor"

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
