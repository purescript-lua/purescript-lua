{- | Lift the pure subset of foreign (FFI) values into the IR (issue #178).

A polymorphic hot path bottoms out in opaque curried foreigns —
@intAdd@, @ordIntImpl@, @refEq@, @boolConj@ — that the IR optimizer
cannot see through, because to the IR a foreign body is just text. This
pass translates the /pure return-tree subset/ of such a body, taken from
the actual fork source parsed by
'Language.PureScript.Backend.Lua.Linker.Foreign' (issue #173), into IR
primops (Note [IR primops] in "Language.PureScript.Backend.IR.Types").
The existing rewrite rules — beta reduction,
case-of-known-constructor (issue #177), inlining, and constant folding —
then finish the specialization the optimizer could not start.

Which exports are lifted is governed by 'allowlist', a hard contract: an
allowlisted export that fails to lift (a fork update changed its
implementation shape) is a compile error, never a silent performance
cliff. An export /not/ on the allowlist is always left opaque, even if it
happens to be liftable.

Deriving the semantics from the fork source, rather than a hand-written
registry of qualified-name → IR mappings, is what makes registry drift
against the package set impossible by construction — the payoff of
Lua's tiny grammar (issue #178).

The same machinery lifts the @run@ half of the @*.Uncurried@ wrappers
(issue #198): @runFn3@ becomes @\\fn a b c -> AppN fn [a, b, c]@ and
@runSTFn2@ becomes @\\fn a b -> Abs _ (AppN fn [a, b])@ (the trailing
effect thunk is a unary lambda with an unused parameter). Marked
inline-always like every lifted accessor, a saturated call site collapses
to a single n-ary Lua call after beta reduction; the effect thunk — run
in statement position by magic-do's 'EffectRunArg' application — is then
shed at code generation ('Language.PureScript.Backend.Lua.fromIR'),
turning @runSTFn2(pushImpl)(x)(arr)()@ from four calls and three closures
into one @pushImpl(x, arr)@.

The @mk@ half lifts too (issue #227): @mkFn3@ becomes
@\\fn -> AbsN [a, b, c] (fn(a)(b)(c))@ — the inner multi-parameter
literal is one n-ary 'AbsN' — and the effectful variants run the
re-curried call by applying it to the 'EffectRunArg' marker
(@mkEffectFn2@'s trailing @fn(a)(b)()@). Inlined at a definition site
like @add3 = mkFn3 \\a b c -> …@, beta reduction leaves the n-ary
literal itself: zero closures per call, and the @mk@ accessors drop out
of the emitted FFI tables just like the @run@ ones.

= What lifts

The translatable subset, mirroring the shapes the prelude forks actually
use:

  * function literals → one n-ary 'AbsN' binding every parameter at a
    single call (a curried chain is nested unary 'Abs'); varargs and
    duplicate parameter names decline (Lua binds the body's reference
    to the /last/ same-named parameter — an 'AbsN' would miscompile
    it);
  * a zero-parameter function literal (the @*.Uncurried@ effect thunk,
    @function() … end@) → a unary 'Abs' with an unused parameter;
  * a call @fn(a, b, …)@ → the n-ary 'AppN' node (issue #198); a
    nullary @fn()@ — the trailing effect run of the @mk{ST,Effect}FnN@
    wrappers — becomes an application to the 'EffectRunArg' marker
    (issue #227); a literal-lambda head called at any arity other than
    its own declines (Note [n-ary application]), the marker counting
    as one argument;
  * @return@ / @if … then … else@ trees (an @elseif@ is a nested @if@ in
    the else branch) → 'IfThenElse', provided every branch returns a
    value (a branch that falls through to @nil@ does not lift);
  * the binary operators of Note [IR primops] and @==@/@~=@ → 'PrimBinOp'
    / 'Eq' / 'PrimNot';
  * the unary @#@ → 'PrimLen' (issue #247), which is how the one-line
    @length@ exports of the array and string forks —
    @function(xs) return #xs end@ — become the VM's own length opcode
    instead of a foreign-table read plus a call frame per use;
  * integer, float, and boolean literals;
  * a reference to a parameter in scope, or to a @local@ in the file's
    header (inlined) — this is how @ordIntImpl = (unsafeCoerceImpl)@ and
    the @refEq@ aliases resolve.

Everything else — loops, mutation, varargs, table constructors,
string/char literals — leaves the export opaque (correct for e.g.
@foldlArray@).
-}
module Language.PureScript.Backend.Lua.ForeignLift
  ( liftForeigns
  , liftExport
  , allowlist
  , Error (..)
  ) where

import Control.Monad.Oops (CouldBe, Variant)
import Control.Monad.Oops qualified as Oops
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Tagged (Tagged, untag)
import Language.PureScript.Backend.IR.Inliner qualified as Inline
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (..)
  , QName (..)
  , moduleNameFromString
  , printQName
  , runModuleName
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (Standalone)
  , PrimOp (..)
  , RawExp (AbsN, ForeignImport, ObjectProp)
  , abstraction
  , abstractionN
  , applicationN
  , eq
  , ifThenElse
  , literalBool
  , literalFloat
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , primBinOp
  , primLen
  , primNot
  , refLocal
  , setAnn
  , pattern EffectRunArg
  )
import Language.PureScript.Backend.Lua.Key qualified as Key
import Language.PureScript.Backend.Lua.Linker.Foreign (Source (..))
import Language.PureScript.Backend.Lua.Linker.Foreign qualified as Foreign
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Types
  ( Annotated
  , BinaryOp (..)
  , Comments
  , ExpF (..)
  , ParamF (..)
  , StatementF (..)
  , UnaryOp (..)
  , VarF (..)
  )
import Path (Abs, Dir, Path)
import Text.Show (Show (..))
import Prelude hiding (show)

--------------------------------------------------------------------------------
-- Allowlist -------------------------------------------------------------------

{- | The foreign exports lifted into the IR: the arithmetic, comparison,
boolean, and concatenation core of the prelude (issue #178), both
halves of the @*.Uncurried@ wrappers — @run@ (issue #198) and @mk@
(issue #227) — the identity coercion @Unsafe.Coerce.unsafeCoerce@
(issue #236), whose lifted @λx. x@ beta-reduces away at every applied
site, and the @#@-shaped @length@ exports (issue #247). Membership is a
hard contract (see the module header): a listed export that fails to
lift is a compile error. Broadening the list further is follow-up work.

Two warnings to that follow-up. An export whose body translates is not
thereby worth lifting: @Data.Array.ST.lengthImpl@ has the same
@function(xs) return #xs end@ body as @Data.Array.length@ and is
deliberately absent, because it is an @STFn1@ — a call of it is an effect
statement, and code generation sheds the surrounding effect thunk only
when the thunk's body is a /call/ (the marker case in
"Language.PureScript.Backend.Lua"). A lifted 'PrimLen' body keeps the
thunk, so @lengthImpl(arr)@ would become
@(function() return #arr end)()@ — a closure allocation plus a call where
there was one call. Its operand is also a mutable @STArray@, which the
sharing and pasting the node is subject to elsewhere assume against
(Note [PrimLen reads immutable values]); the unshed thunk holds the node
out of those rules' reach today, and this exclusion does not rely on
that.

And do /not/ list the Effect\/ST core —
@Effect.bindE@\/@pureE@, @Control.Monad.ST.Internal.bind_@\/@pure_@ —
even though its thunk-shaped bodies are technically liftable now that
nullary calls translate. Those very names are the canonical heads
magic-do matches (Note [Canonical Effect/ST heads]); a lifted core
would be inlined into primop trees during the optimizer fixpoint that
runs first, erasing the names and blinding magic-do — no flat @do@
chunks, and no chunked statement sequences keeping the output under
Lua's local-variable limits (issue #19). Lifting the core behind a
marker magic-do understands is tracked as issue #228.
-}
allowlist ∷ Set QName
allowlist =
  Set.fromList
    [ QName (moduleNameFromString modName) (Name exportName)
    | (modName, exportNames) ← entries
    , exportName ← exportNames
    ]
 where
  entries ∷ [(Text, [Text])]
  entries =
    [ ("Data.Semiring", ["intAdd", "intMul"])
    , ("Data.Ring", ["intSub"])
    , ("Data.Ord", ["ordIntImpl", "ordCharImpl"])
    , ("Data.HeytingAlgebra", ["boolConj", "boolDisj", "boolNot"])
    ,
      ( "Data.Eq"
      ,
        [ "refEq"
        , "eqBooleanImpl"
        , "eqIntImpl"
        , "eqNumberImpl"
        , "eqCharImpl"
        , "eqStringImpl"
        ]
      )
    , ("Data.Semigroup", ["concatString"])
    , ("Unsafe.Coerce", ["unsafeCoerce"])
    , -- The @#@-shaped length exports (issue #247). Both take an
      -- immutable operand, an array and a string; the identically-bodied
      -- @Data.Array.ST.lengthImpl@ is absent for the two reasons the
      -- Haddock above spells out.
      ("Data.Array", ["length"])
    , ("Data.String.CodeUnits", ["length"])
    , -- Both halves of the uncurried FFI wrappers: @run@ (issue #198)
      -- and @mk@ (issue #227). @runFn0@/@mkFn0@ are absent by policy,
      -- not liftability: their bodies force a /pure/ @Fn0@ with a
      -- nullary call, which must not be marked an effect run.
      -- @runFn1@/@mkFn1@ are PureScript @id@ with no foreign.

      ( "Data.Function.Uncurried"
      , wrappers "runFn" [2 .. 10] <> wrappers "mkFn" [2 .. 10]
      )
    ,
      ( "Control.Monad.ST.Uncurried"
      , wrappers "runSTFn" [1 .. 10] <> wrappers "mkSTFn" [1 .. 10]
      )
    ,
      ( "Effect.Uncurried"
      , wrappers "runEffectFn" [1 .. 10] <> wrappers "mkEffectFn" [1 .. 10]
      )
    ]

  -- @[prefix<n> | n <- arities]@, e.g. @wrappers "runFn" [2, 3]@ is
  -- @["runFn2", "runFn3"]@.
  wrappers ∷ Text → [Int] → [Text]
  wrappers prefix arities = [prefix <> toText (show n) | n ← arities]

--------------------------------------------------------------------------------
-- Orchestration ---------------------------------------------------------------

{- | Move every allowlisted foreign accessor of the linked module out of
the foreigns and into the ordinary bindings as its lifted IR, leaving
all other foreigns opaque. Runs before the IR optimizer, so the lifted
primops flow through the whole pipeline.

A lifted export becomes a plain 'Standalone' binding rather than staying
in 'uberModuleForeigns': it is no longer an FFI accessor, and dead-code
elimination only understands the 'ForeignImport' / 'ObjectProp' shapes
among the foreigns (see Note [Foreign bindings structure emitted by the
Linker]). Once the accessor is gone, DCE prunes the export's name from
the module's 'ForeignImport' (nothing reads it off the @foreign@ import
anymore), so the source row is dropped from the emitted FFI; if every
export of a module lifts, its 'ForeignImport' vanishes entirely.

A listed export that is missing from its source, or present but not
liftable, aborts compilation with an 'Error' — the allowlist contract.
-}
liftForeigns
  ∷ ∀ e
   . e `CouldBe` Error
  ⇒ Tagged "foreign" (Path Abs Dir)
  → UberModule
  → ExceptT (Variant e) IO UberModule
liftForeigns
  foreignDir
  uber@UberModule {uberModuleForeigns, uberModuleBindings} = do
    sources ← parseNeededSources
    results ← forM uberModuleForeigns \entry@(qname, expr) →
      case expr of
        ObjectProp ann _ _ | qname `Set.member` allowlist →
          case liftAccessor sources qname of
            -- A lifted body exists to beta-reduce at saturated call
            -- sites, so it is marked @inline always@ here: without the
            -- annotation a multi-use lifted body — an abstraction, not
            -- a cheap projection — would stay a shared binding and its
            -- call sites would never reduce (see Note [Inline
            -- annotations and inlining heuristics]). An explicit
            -- pragma still wins.
            Just lifted →
              pure (Right (qname, setAnn (ann <|> Just Inline.Always) lifted))
            Nothing → Oops.throw (NotLiftable qname)
        _ → pure (Left entry)
    let (keptForeigns, liftedBindings) = partitionEithers results
    pure
      uber
        { uberModuleForeigns = keptForeigns
        , uberModuleBindings =
            map Standalone liftedBindings <> uberModuleBindings
        }
   where
    -- The paths of every foreign module, keyed by module name.
    paths ∷ Map ModuleName FilePath
    paths =
      Map.fromList
        [ (modname, path)
        | (_qname, ForeignImport _ann modname path _names) ← uberModuleForeigns
        ]

    -- Parse only the modules that actually contribute an allowlisted export.
    parseNeededSources ∷ ExceptT (Variant e) IO (Map ModuleName Source)
    parseNeededSources =
      fmap Map.fromList . forM (Set.toList neededModules) $ \modname → do
        path ←
          Map.lookup modname paths
            & maybe (Oops.throw (NoForeignFor modname)) pure
        parsed ←
          liftIO (Foreign.parseForeignSource (untag foreignDir) path)
        source ← either (Oops.throw . ParseError) pure parsed
        pure (modname, source)
     where
      neededModules ∷ Set ModuleName
      neededModules =
        Set.fromList
          [ qnameModuleName qname
          | (qname, ObjectProp {}) ← uberModuleForeigns
          , qname `Set.member` allowlist
          ]

-- | Lift a single accessor, given the already-parsed sources.
liftAccessor ∷ Map ModuleName Source → QName → Maybe Exp
liftAccessor sources QName {qnameModuleName, qnameName} = do
  source ← Map.lookup qnameModuleName sources
  liftExport source qnameName

--------------------------------------------------------------------------------
-- The lifter ------------------------------------------------------------------

{- | Lift one named export of a parsed foreign 'Source' to IR, or 'Nothing'
when its body falls outside the translatable subset (see the module
header). Header @local@s are available for inlining, which is how the
@refEq@ aliases and @ordIntImpl = (unsafeCoerceImpl)@ resolve.
-}
liftExport ∷ Source → Name → Maybe Exp
liftExport Source {header, exports} Name {nameToText} = do
  luaExp ← Map.lookup nameToText exportsByName
  liftLuaExp (headerEnv header) Set.empty luaExp
 where
  exportsByName ∷ Map Text (ExpF Comments)
  exportsByName =
    Map.fromList
      [ (Lua.toText (Key.toSafeName key), value)
      | (key, (_comments, value)) ← toList exports
      ]

-- | The header @local@ bindings available for inlining into an export.
headerEnv ∷ [Annotated Comments StatementF] → Map Lua.Name (ExpF Comments)
headerEnv statements =
  Map.fromList (mapMaybe binding statements)
 where
  binding ∷ Annotated Comments StatementF → Maybe (Lua.Name, ExpF Comments)
  binding (_comments, statement) = case statement of
    Local (name :| []) [(_ann, value)] → Just (name, value)
    LocalFunction name params body → Just (name, Function params body)
    _ → Nothing

{- | Translate a Lua expression in the pure subset to IR. 'env' holds the
header @local@s reachable by name; 'bound' holds the parameters of the
enclosing function literals.
-}
liftLuaExp
  ∷ Map Lua.Name (ExpF Comments) → Set Lua.Name → ExpF Comments → Maybe Exp
liftLuaExp env bound = \case
  Paren (_ann, e) → liftLuaExp env bound e
  Integer i → Just (literalInt i)
  Float f → Just (literalFloat f)
  Boolean b → Just (literalBool b)
  Var (_ann, VarName name)
    | Set.member name bound → Just (refLocal (irName name))
    -- Inline a header local. Drop it from the environment first, so a
    -- self- or mutually-recursive header binding runs out of names and
    -- declines rather than looping.
    | Just e ← Map.lookup name env → liftLuaExp (Map.delete name env) bound e
    | otherwise → Nothing
  UnOp LogicalNot (_ann, a) → primNot <$> liftLuaExp env bound a
  UnOp HashOp (_ann, a) → primLen <$> liftLuaExp env bound a
  BinOp op (_ann, a) (_ann', b) → do
    a' ← liftLuaExp env bound a
    b' ← liftLuaExp env bound b
    liftBinOp op a' b'
  -- A function literal binds every parameter at one call, so it lifts
  -- to a single n-ary 'AbsN' (issue #227) — nested unary 'Abs' would
  -- misapply when curried (it would fail the WellApplied invariant).
  -- Varargs decline (the length check fails on the filtered-out
  -- 'ParamVararg'), and so do duplicate parameter names: Lua binds the
  -- body's reference to the /last/ same-named parameter, which an
  -- 'AbsN' would silently miscompile.
  Function params body
    | Just names ← nonEmpty [name | (_ann, ParamNamed name) ← params]
    , length names == length params
    , let paramSet = Set.fromList (toList names)
    , Set.size paramSet == length names →
        abstractionN (paramNamed . irName <$> names)
          <$> liftBlock env (Set.union bound paramSet) body
  -- A zero-parameter function literal is the effect thunk of the
  -- @run{ST,Effect}FnN@ wrappers: @function() return fn(a, b) end@. It
  -- lifts to a unary 'Abs' with an unused parameter — the shape
  -- magic-do runs in statement position and codegen then sheds, so a
  -- saturated site fuses the thunk away entirely (issue #198).
  Function [] body →
    abstraction paramUnused <$> liftBlock env bound body
  -- A call @fn(a, b, …)@ — the body of the @runFnN@ wrappers — lifts to
  -- the n-ary 'AppN' node (issue #198). A nullary call @fn()@ — the
  -- trailing effect run of the @mk{ST,Effect}FnN@ wrappers — lifts as
  -- an application to the 'EffectRunArg' marker (issue #227): the shape
  -- magic-do emits, which the Lua backend erases back to an empty
  -- argument list.
  FunctionCall (_ann, fn) args → do
    fn' ← liftLuaExp env bound fn
    args' ← case nonEmpty args of
      Nothing → Just (EffectRunArg noAnn :| [])
      Just ne → traverse (\(_ann', a) → liftLuaExp env bound a) ne
    -- A literal-lambda head (an inlined header local, or a parenthesized
    -- function literal) must be called at exactly its own arity: any
    -- other count would build an ill-formed 'AppN' (Note [n-ary
    -- application]). Splitting the spine instead would change the
    -- program — Lua drops surplus arguments — so a mismatch declines.
    -- The marker counts as one argument: a nullary call passes a thunk
    -- head and declines any wider literal.
    case fn' of
      AbsN _ params _ | length params /= length args' → Nothing
      _ → Just (applicationN fn' args')
  _ → Nothing

{- | Translate a block that must be a pure return tree: a single @return@
of one value, or a single @if@ whose branches are themselves such trees.
A branch that falls through without returning (an @if@ with an empty
else, a multi-statement body) does not lift.
-}
liftBlock
  ∷ Map Lua.Name (ExpF Comments)
  → Set Lua.Name
  → [Annotated Comments StatementF]
  → Maybe Exp
liftBlock env bound = \case
  [(_ann, Return [(_ann', e)])] → liftLuaExp env bound e
  [(_ann, IfThenElse (_ann', cond) thenBlock elseBlock)] →
    ifThenElse
      <$> liftLuaExp env bound cond
      <*> liftBlock env bound thenBlock
      <*> liftBlock env bound elseBlock
  _ → Nothing

{- | The inverse of the primop lowering
('Language.PureScript.Backend.Lua.luaBinaryOp'), plus @==@/@~=@ onto the
'Eq' node (Note [IR primops]). Operators outside the subset — bitwise,
floor division, exponent — decline.
-}
liftBinOp ∷ BinaryOp → Exp → Exp → Maybe Exp
liftBinOp op a b = case op of
  Add → Just (primBinOp PrimAdd a b)
  Sub → Just (primBinOp PrimSub a b)
  Mul → Just (primBinOp PrimMul a b)
  FloatDiv → Just (primBinOp PrimDiv a b)
  Mod → Just (primBinOp PrimMod a b)
  Concat → Just (primBinOp PrimConcat a b)
  LessThan → Just (primBinOp PrimLt a b)
  LessThanOrEqualTo → Just (primBinOp PrimLe a b)
  GreaterThan → Just (primBinOp PrimGt a b)
  GreaterThanOrEqualTo → Just (primBinOp PrimGe a b)
  And → Just (primBinOp PrimAnd a b)
  Or → Just (primBinOp PrimOr a b)
  EqualTo → Just (eq a b)
  NotEqualTo → Just (primNot (eq a b))
  _ → Nothing

irName ∷ Lua.Name → Name
irName = Name . Lua.toText

--------------------------------------------------------------------------------
-- Errors ----------------------------------------------------------------------

-- | A breach of the allowlist contract, or a failure to read a source.
data Error
  = {- | An allowlisted export is present but its implementation shape is
    outside the translatable subset — most likely a fork update. The
    allowlist must be corrected (or the export dropped from it).
    -}
    NotLiftable QName
  | {- | An allowlisted export names a module with no foreign source in the
    linked module. Should not arise for a well-formed allowlist.
    -}
    NoForeignFor ModuleName
  | -- | The module's foreign source failed to parse or interpret.
    ParseError Foreign.Error
  deriving stock (Eq)

instance Show Error where
  show = \case
    NotLiftable qname →
      "Foreign export "
        <> toString (printQName qname)
        <> " is on the lift allowlist but its implementation is not\n"
        <> "liftable (the foreign source shape likely changed in a fork\n"
        <> "update). Fix the allowlist in\n"
        <> "Language.PureScript.Backend.Lua.ForeignLift, or update the fork."
    NoForeignFor modname →
      "Foreign export in module "
        <> toString (runModuleName modname)
        <> " is on the lift allowlist but the module has no foreign source."
    ParseError err → show err
