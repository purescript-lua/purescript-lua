{- | Unbox non-escaping Ref/STRef cells to mutable Lua locals (issue #239).

A @Ref@/@STRef@ cell compiles to a one-field heap table: the foreign
@new@ allocates @{value = v}@, @read@ returns @ref.value@, @write@ and
@modify@ assign it. When the cell never flows anywhere as a whole value,
the table buys nothing over a plain Lua local — so a @Let@-bound run of
@new@ whose cell qualifies lowers to @local r = v@, a @read@ run to @r@
itself, and @write@/@modify@ runs to plain assignments. The per-cell
table allocation and the per-operation field indirection disappear.

== Why capture is not escape

A Lua local read or assigned from an inner @function@ becomes an
upvalue: a shared, mutable slot that outlives the block when a closure
holds it, with every closure created in the same scope sharing the one
slot. That is exactly the aliasing behaviour of the @{value = …}@ table,
so occurrences of the cell under lambdas — loop bodies, nested magic-do
chunks — need no special treatment: the assignment @r = v@ mutates the
shared slot wherever it executes. The only thing the table provides that
a local cannot is first-class identity — the cell passed to an unknown
function, stored in a structure, or returned. The analysis therefore
asks one question: is every occurrence of the cell the reference
argument of a recognised operation? Any other occurrence keeps the cell
boxed.

== Recognition

Operations are recognised by qualified name, the identity that survives
linking (Note [Canonical Effect/ST heads]), in the two forms a foreign
takes at codegen time — the plain imported reference and the dissolved
foreign-accessor read — same as the loop matcher in
"Language.PureScript.Backend.Lua.NativeLoop". The table covers the cell
primitives of @Effect.Ref@ and @Control.Monad.ST.Internal@ (@_new@/@new@,
@read@, @write@, @modifyImpl@) plus the ST functor's foreign @map_@ as a
wrapper: @void (modify f r)@ inlines to @map_ (\\_ → unit) (modifyImpl f
r)@, so without the wrapper the bread-and-butter @modify_@ shape would
keep every cell boxed. @Effect.Ref.newWithSelf@ hands the cell to its
own initialiser — inherent escape — and is deliberately absent.
@Effect@'s functor has no foreign @map@ (it goes through a lazily tied
dictionary), so Effect cells survive only direct @read@/@write@/@modify'@
uses; the dictionary shapes fall outside the table and keep their cells
boxed, which is always sound.

== Where uses may sit

A recognised operation lowers in two positions:

  * /Run/ position — the application carries magic-do's
    'IR.EffectRunArg' marker. This is where magic-do puts every
    statement and chain tail, and where
    'Language.PureScript.Backend.Lua.NativeLoop.runStatements' runs a
    loop's literal body lambda once per iteration (it attaches the same
    marker before compiling), so the analysis checks such a lambda body
    as if the marker were present.

  * Everything else is /value/ position: the operation's thunk is a
    first-class value (stored, pre-bound and called per iteration, …).
    Lowering there would have to reproduce the boxed thunk's evaluation
    timing; the analysis simply rejects the cell instead, which keeps
    the table and the foreign implementation — a missed optimisation,
    never a miscompile.

== What a run lowers to

Each run becomes statements plus a value expression:

  * @read r@ — no statements; the value is @r@.
  * @write v r@ — @r = v@; the value is @nil@ for @Effect.Ref@ (its
    foreign returns nothing) and @r@ for ST (its foreign returns the
    written value).
  * @modifyImpl f r@ with @f@ a literal lambda ending in a manifest
    @{state, value}@ record — the beta the boxed closure call would
    perform, done at emission: bind the parameter to @r@, emit the
    body's @Let@ spine as locals, pre-bind the record fields in written
    order, assign the state field to @r@ and pass the value field on.
    The record is never allocated. Any other @f@ falls back to
    @local t = f(r); r = t.state@ with value @t.value@.
  * @map_ g m@ — the statements of @m@'s run; the value applies @g@ to
    @m@'s value. A literal lambda @g@ is bound directly (its parameter
    becomes a local holding @m@'s value), matching the boxed call's
    timing; a non-atomic non-literal @g@ is pre-bound before @m@'s
    statements, since the boxed code evaluates @map_@'s argument before
    running the action.

A run in statement position ('lowerOpRunBinding') scopes its lowering in
a @do … end@ block whenever it declares locals: magic-do budgets ~150
statements per chunk, and modify spines spilling unscoped locals into
the enclosing function could breach Lua's @LUAI_MAXVARS@ (200 active
locals). A run in expression position compiles to a chunk ending in
@return value@; consumers either splice it as a tail or wrap it in a
scope call, and 'NativeLoop.runStatements' rewrites the tail return into
evaluation statements when the run's value is discarded.
-}
module Language.PureScript.Backend.Lua.RefUnbox
  ( OpUse
  , matchNewRun
  , matchOpRun
  , usedOnlyThroughOps
  , lowerOpRun
  , lowerOpRunBinding
  ) where

import Control.Lens (toListOf)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Linker (foreignAccessorQName)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.NativeLoop qualified as NativeLoop
import Language.PureScript.Backend.Lua.Types qualified as Lua

--------------------------------------------------------------------------------
-- Recognition -----------------------------------------------------------------

{- | A recognised use of a cell: the saturated application of one of the
operations to the cell (before any 'IR.EffectRunArg'), carrying the
non-reference arguments.
-}
data OpUse
  = ReadUse
  | -- | The written value.
    WriteUse WriteResult IR.Exp
  | -- | The @s → {state, value}@ function.
    ModifyUse IR.Exp
  | -- | @map_ g@ around an inner use.
    MapUse IR.Exp OpUse

{- | What a run of the foreign @write@ evaluates to: the @Effect.Ref@
implementation returns nothing (@nil@ at the call site), the ST one
returns the written value.
-}
data WriteResult = WriteResultNil | WriteResultWritten

data OpKind = ReadKind | WriteKind WriteResult | ModifyKind | MapKind

{- | The cell operations, keyed by the qualified name recognition
matches on (see the module haddock).
-}
opKinds ∷ Map IR.QName OpKind
opKinds =
  Map.fromList
    [ (IR.QName effectRefModule (IR.Name "read"), ReadKind)
    , (IR.QName stModule (IR.Name "read"), ReadKind)
    , (IR.QName effectRefModule (IR.Name "write"), WriteKind WriteResultNil)
    , (IR.QName stModule (IR.Name "write"), WriteKind WriteResultWritten)
    , (IR.QName effectRefModule (IR.Name "modifyImpl"), ModifyKind)
    , (IR.QName stModule (IR.Name "modifyImpl"), ModifyKind)
    , (IR.QName stModule (IR.Name "map_"), MapKind)
    ]

-- | The cell allocators.
newNames ∷ Set IR.QName
newNames =
  Set.fromList
    [ IR.QName effectRefModule (IR.Name "_new")
    , IR.QName stModule (IR.Name "new")
    ]

effectRefModule, stModule ∷ IR.ModuleName
effectRefModule = IR.ModuleName "Effect.Ref"
stModule = IR.ModuleName "Control.Monad.ST.Internal"

{- | Recognise the run of a cell allocation: @new v EffectRunArg@.
Yields the initial value.
-}
matchNewRun ∷ IR.Exp → Maybe IR.Exp
matchNewRun = \case
  IR.AppN _ann inner (IR.EffectRunArg _ :| []) → do
    let (hd, args) = IR.unwindApp inner
    qname ← headQName hd
    guard (Set.member qname newNames)
    case args of
      [v] → Just v
      _ → Nothing
  _ → Nothing

{- | Recognise the run of a cell operation: @use EffectRunArg@. Yields
the cell (a local binder under GUC) and the parsed use.
-}
matchOpRun ∷ IR.Exp → Maybe (IR.Name, OpUse)
matchOpRun = \case
  IR.AppN _ann inner (IR.EffectRunArg _ :| []) → matchOpUse inner
  _ → Nothing

matchOpUse ∷ IR.Exp → Maybe (IR.Name, OpUse)
matchOpUse expr = do
  let (hd, args) = IR.unwindApp expr
  kind ← (`Map.lookup` opKinds) =<< headQName hd
  case (kind, args) of
    (ReadKind, [IR.Ref _ (IR.Local cell)]) →
      Just (cell, ReadUse)
    (WriteKind result, [v, IR.Ref _ (IR.Local cell)]) →
      Just (cell, WriteUse result v)
    (ModifyKind, [f, IR.Ref _ (IR.Local cell)]) →
      Just (cell, ModifyUse f)
    (MapKind, [g, inner]) →
      second (MapUse g) <$> matchOpUse inner
    _ → Nothing

{- | The qualified name an operation head denotes: a plain imported
reference, or the dissolved foreign-accessor read — the two forms of
'Language.PureScript.Backend.Lua.NativeLoop.headQName'.
-}
headQName ∷ IR.Exp → Maybe IR.QName
headQName = \case
  IR.Ref _ann (IR.Imported modname name) → Just (IR.QName modname name)
  expr → foreignAccessorQName expr

--------------------------------------------------------------------------------
-- Analysis --------------------------------------------------------------------

{- | Does every occurrence of the cell in the given expressions sit in a
position the lowering rewrites? Run positions qualify — a direct
'IR.EffectRunArg' run anywhere, and the body of a literal loop lambda
(run per iteration by 'NativeLoop.runStatements'). A naked occurrence —
the cell flowing somewhere as a whole value — disqualifies it.
-}
usedOnlyThroughOps ∷ IR.Name → [IR.Exp] → Bool
usedOnlyThroughOps cell = all ok
 where
  ok ∷ IR.Exp → Bool
  ok expr
    | Just (r, use) ← matchOpRun expr =
        if r == cell
          then all ok (opUseArgs use)
          else all ok (toListOf IR.subexpressions expr)
    | Just loop ← NativeLoop.matchLoopRun expr = case loop of
        NativeLoop.ForeachLoop arr f → ok arr && okLoopFunction f
        NativeLoop.ForRangeLoop lo hi f → ok lo && ok hi && okLoopFunction f
        -- The while condition and a non-thunk body are compiled as
        -- values (pre-bound, called per iteration); a thunk body's
        -- statements carry their own run markers. Plain recursion
        -- checks all of these correctly.
        NativeLoop.WhileLoop cond body → ok cond && ok body
    | IR.Ref _ (IR.Local r) ← expr = r /= cell
    | otherwise = all ok (toListOf IR.subexpressions expr)

  -- The literal unary lambda of a for/foreach run has its body run per
  -- iteration: a thunk body is spliced (its statements carry their own
  -- run markers), any other body is run as a whole, so it is checked
  -- with the marker 'NativeLoop.runStatements' attaches before
  -- compiling. A non-lambda argument is pre-bound and called: a value.
  okLoopFunction ∷ IR.Exp → Bool
  okLoopFunction = \case
    IR.AbsN _ (_param :| []) body
      | IR.AbsN _ (IR.ParamUnused _ :| []) _ ← body → ok body
      | otherwise → ok (IR.App IR.noAnn body (IR.EffectRunArg IR.noAnn))
    f → ok f

{- | The non-reference arguments of a use: ordinary expressions the
analysis recurses into and the lowering compiles.
-}
opUseArgs ∷ OpUse → [IR.Exp]
opUseArgs = \case
  ReadUse → []
  WriteUse _result v → [v]
  ModifyUse f → [f]
  MapUse g inner → g : opUseArgs inner

--------------------------------------------------------------------------------
-- Lowering --------------------------------------------------------------------

{- | Lower the run of a recognised use of an unboxed cell to statements
plus the run's value. The first argument compiles an IR expression to a
Lua expression (the caller's own recursion), the second mints a fresh
Lua-side local name from a prefix.
-}
lowerOpRun
  ∷ ∀ m
   . Monad m
  ⇒ (IR.Exp → m Lua.Exp)
  → (Text → m Name.Name)
  → Name.Name
  → OpUse
  → m ([Lua.Statement], Lua.Exp)
lowerOpRun compileExp fresh cell = go
 where
  go ∷ OpUse → m ([Lua.Statement], Lua.Exp)
  go = \case
    ReadUse → pure ([], Lua.varName cell)
    WriteUse result v → do
      v' ← compileExp v
      pure
        ( [Lua.assignVar cell v']
        , case result of
            WriteResultNil → Lua.Nil
            WriteResultWritten → Lua.varName cell
        )
    ModifyUse f → lowerModify f
    MapUse g inner → case g of
      -- \_ → gbody: the boxed call evaluates gbody after running the
      -- inner action, its value discarded (but still evaluated — a
      -- non-atomic value is a call whose effects must be kept).
      IR.AbsN _ (IR.ParamUnused _ :| []) gbody → do
        (stmts, innerValue) ← go inner
        gbody' ← compileExp gbody
        pure (stmts <> NativeLoop.dropValue innerValue, gbody')
      -- \x → gbody: bind the inner value to the parameter and continue
      -- with the body — the beta the boxed closure call performs.
      IR.AbsN _ (IR.ParamNamed _ x :| []) gbody → do
        (stmts, innerValue) ← go inner
        gbody' ← compileExp gbody
        pure (stmts <> [Lua.local1 (fromName x) innerValue], gbody')
      -- Anything else: call the compiled function on the inner value.
      -- The boxed code evaluates the function expression before running
      -- the action, so a non-atomic one is pre-bound to keep that order.
      _ → do
        g' ← compileExp g
        (gPre, gAtom) ← preBind "$g" g'
        (stmts, innerValue) ← go inner
        pure (gPre <> stmts, Lua.functionCall gAtom [innerValue])

  lowerModify ∷ IR.Exp → m ([Lua.Statement], Lua.Exp)
  lowerModify f
    | IR.AbsN _ (param :| []) fbody ← f
    , Just (spine, fields) ← recordTail fbody = do
        let paramStmt = case param of
              IR.ParamNamed _ann s → [Lua.local1 (fromName s) (Lua.varName cell)]
              IR.ParamUnused _ann → []
        spineStmts ← forM spine \(name, expr) →
          Lua.local1 (fromName name) <$> compileExp expr
        -- The record build evaluates its fields in written order before
        -- the foreign assigns the state; pre-binding non-atomic fields
        -- keeps that order across the cell assignment.
        let ((prop1, fieldExp1), (_prop2, fieldExp2)) = fields
        (pre1, atom1) ← preBind "$v" =<< compileExp fieldExp1
        (pre2, atom2) ← preBind "$v" =<< compileExp fieldExp2
        let fieldStmts = pre1 <> pre2
            (stateExp, valueExp)
              | prop1 == statePropName = (atom1, atom2)
              | otherwise = (atom2, atom1)
        pure
          ( paramStmt
              <> spineStmts
              <> fieldStmts
              <> [Lua.assignVar cell stateExp]
          , valueExp
          )
    | otherwise = do
        f' ← compileExp f
        t ← fresh "$t"
        pure
          (
            [ Lua.local1 t (Lua.functionCall f' [Lua.varName cell])
            , Lua.assignVar cell (Lua.varField (Lua.varName t) stateName)
            ]
          , Lua.varField (Lua.varName t) valueName
          )

  preBind ∷ Text → Lua.Exp → m ([Lua.Statement], Lua.Exp)
  preBind prefix e
    | isAtom e = pure ([], e)
    | otherwise = do
        name ← fresh prefix
        pure ([Lua.local1 name e], Lua.varName name)

  isAtom ∷ Lua.Exp → Bool
  isAtom = \case
    Lua.Nil → True
    Lua.Boolean _ → True
    Lua.Integer _ → True
    Lua.Float _ → True
    Lua.String _ → True
    Lua.Var (Lua.Ann (Lua.VarName _)) → True
    _ → False

{- | Lower the run of a recognised use in @Let@-statement position: the
binder receives the run's value (or nothing, for the discard binder).
A lowering that declares locals is scoped in a @do … end@ block so
modify spines cannot accumulate against the enclosing function's
@LUAI_MAXVARS@ budget; the binder, declared outside, is assigned within.
-}
lowerOpRunBinding
  ∷ ∀ m
   . Monad m
  ⇒ (IR.Exp → m Lua.Exp)
  → (Text → m Name.Name)
  → Maybe Name.Name
  → Name.Name
  → OpUse
  → m [Lua.Statement]
lowerOpRunBinding compileExp fresh binder cell use = do
  (stmts, value) ← lowerOpRun compileExp fresh cell use
  let declaresLocals = any declaresLocal stmts
  pure case binder of
    Nothing
      | declaresLocals →
          [Lua.Do (Lua.ann <$> (stmts <> NativeLoop.dropValue value))]
      | otherwise → stmts <> NativeLoop.dropValue value
    Just name
      | declaresLocals →
          [ Lua.local0 name
          , Lua.Do (Lua.ann <$> (stmts <> [Lua.assignVar name value]))
          ]
      | otherwise → stmts <> [Lua.local1 name value]
 where
  declaresLocal ∷ Lua.Statement → Bool
  declaresLocal = \case
    Lua.Local {} → True
    Lua.LocalFunction {} → True
    _ → False

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

{- | Split a modify function body into its @Let@ spine and the final
manifest two-field @{state, value}@ record build, fields in written
order. 'Nothing' when the body has any other tail, a recursive spine
group, or extra fields — those fall back to calling the compiled
function.
-}
recordTail
  ∷ IR.Exp
  → Maybe ([(IR.Name, IR.Exp)], ((IR.PropName, IR.Exp), (IR.PropName, IR.Exp)))
recordTail = \case
  IR.LiteralObject _ann [field1@(p1, _), field2@(p2, _)]
    | (p1 == statePropName && p2 == valuePropName)
        || (p1 == valuePropName && p2 == statePropName) →
        Just ([], (field1, field2))
  IR.Let _ann bindings body → do
    spine ← forM (toList bindings) \case
      IR.Standalone (_ann, name, expr) → Just (name, expr)
      IR.RecursiveGroup _ → Nothing
    first (spine <>) <$> recordTail body
  _ → Nothing

statePropName, valuePropName ∷ IR.PropName
statePropName = IR.PropName "state"
valuePropName = IR.PropName "value"

stateName, valueName ∷ Name.Name
stateName = Name.unsafeName "state"
valueName = Name.unsafeName "value"

fromName ∷ IR.Name → Name.Name
fromName = Name.makeSafe . IR.nameToText
