{- | Flatten deeply-nested @do@\/@>>=@ chains for arbitrary (non-Effect\/ST)
monads, so they load under Lua 5.1's parser-nesting cap.

A straight-line @do@ block desugars to a right-nested tree of continuation
closures:

>   bind m1 (\x1 -> bind m2 (\x2 -> … bind mn (\xn -> final)))

Past ~200 nesting levels Lua's parser refuses to load the chunk with
@chunk has too many syntax levels@ (@LUAI_MAXCCALLS@) — a correctness failure
unique to the Lua backend (issue #104). 'Language.PureScript.Backend.IR.MagicDo'
already fixes this for 'Effect'\/'ST', whose computations are thunks and so can
be lowered to a flat statement sequence. That lowering is impossible here:
for an arbitrary monad @bind m k@ is an opaque call whose control flow lives
/inside/ @bind@ (Maybe short-circuits, lists call @k@ 0..N times, State threads
context), so the chain cannot become sequential statements.

== The transform: lambda-lifting the continuation chain

The only monad-agnostic fix is lambda-lifting (Johnsson): split the chain into
segments of at most 'segmentSize' steps and turn each cut's tail into a named
helper @$kontN@ whose free continuation variables are passed as explicit
parameters. The original

>   bind m1 (\x1 -> … bind mC (\xC -> <tail>) …)

becomes (last-defined-first, so each helper only references already-defined
ones — see Note [Sequential scoping of Let bindings]):

>   let $kontM = \live… \xK -> <segment M>
>       …
>       $kont2 = \live… \xC -> bind m_{C+1} (\… -> … $kont3 live… …)
>   in  bind m1 (\x1 -> … bind mC (\xC -> $kont2 live… xC) …)

Each helper body and the @let@ body nest at most 'segmentSize' binds deep, so
the whole expression stays flat regardless of the original chain length.

This relocates closures and forwards their environment but never reorders,
drops, or duplicates a @bind@\/@k@ call, so it is semantics-preserving for
/any/ monad — strict Lua included: the introduced @$kontN@ calls pass only
variables (no evaluation reordering) and @let@-binding a helper does not run its
body. Recognition precision therefore only governs /which/ expressions are
restructured, not correctness.

== De Bruijn safety: no shifting

The pass runs after 'renameShadowedNames'
(see Note [Locals are uniquely named after renameShadowedNames]), so every local
is uniquely named. A helper reuses the chain's own binder names as its
parameters: moving a sub-expression under a fresh binder of the /same/ name
leaves every @Ref … 0@ pointing at the same value (there is no other binder of
that name in between), and the call site references the live variables by name
at index 0 because they are still in scope there. Helper names are minted as
@$kontN@ — the @$@ prefix cannot collide with a PureScript identifier or with
'renameShadowedNames'' digit-suffix scheme — so no 'shift'\/'unshift' is needed.

== Why it must run after 'magicDo'

This pass does /not/ check whether the monad is 'Effect'\/'ST': 'magicDo' runs
first (the previous step of 'optimizedUberModule') and rewrites every
'Effect'\/'ST' bind chain into a 'Let' thunk, so the only bind chains that
reach this pass are non-'Effect'\/'ST'. Were the order reversed this pass would
lambda-lift those chains too — still correct, but redundant and worse code than
the magic-do statement sequence.

== Bail-out

Lambda-lifting bounds /nesting/ but the innermost closure of a segment captures
the segment's own binders plus the forwarded live set as upvalues, and Lua 5.1
caps a function at 60 upvalues (@LUAI_MAXUPVALUES@, see @docs\/QUIRKS.md@). When
the live set at a cut is too large the pass bails (returns 'NoChange', leaving
the chain nested): the program then overflows exactly as it does today, now
caught by the post-codegen nesting detector
('Language.PureScript.Backend.Lua.NestingCheck'). Packing the environment into a
single table to cut the upvalue cost to one is a future upgrade.
-}
module Language.PureScript.Backend.IR.FlattenDeepBinds
  ( flattenDeepBinds
  ) where

import Control.Lens (universeOf)
import Data.List qualified as List
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , PropName (..)
  , QName (..)
  , Qualified (..)
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , Index (..)
  , Parameter (..)
  , RawExp (..)
  , RewriteMod (..)
  , RewriteRuleM
  , Rewritten (..)
  , countFreeRefs
  , noAnn
  , rewriteExpTopDownM
  , subexpressions
  , substitute
  , unshift
  )

{- | Flatten deeply-nested non-Effect\/ST bind chains in every binding and
export of the module. A single @$kontN@ counter is threaded across the whole
module so the minted helper names are globally unique.
-}
flattenDeepBinds ∷ UberModule → UberModule
flattenDeepBinds uber@UberModule {uberModuleBindings, uberModuleExports} =
  uber
    { uberModuleBindings = bindings'
    , uberModuleExports = exports'
    }
 where
  (bindings', exports') = evalState action 0

  action ∷ State Int ([Grouping (QName, Exp)], [(Name, Exp)])
  action =
    (,)
      <$> traverse (traverse (traverse rewrite)) uberModuleBindings
      <*> traverse (traverse rewrite) uberModuleExports

  rewrite ∷ Exp → State Int Exp
  rewrite expr =
    rewriteExpTopDownM (flattenRule (mkResolve topLevel expr)) expr

  -- Top-level bindings, so a chain head specialised to a module-local alias
  -- (e.g. @Module.bind = dictBindMaybe.bind@) resolves back to its definition.
  -- All group members are indexed, not just 'Standalone' ones: an alias that
  -- lands in a 'RecursiveGroup' must still resolve, or its chain stops being
  -- recognised and flattened.
  topLevel ∷ Map QName Exp
  topLevel =
    Map.fromList
      [ (qname, expr)
      | grouping ← uberModuleBindings
      , (qname, expr) ← toList grouping
      ]

{- | Resolve a chain-head reference to its definition.

  * 'Imported' names resolve through the module's top-level bindings.

  * 'Local' names resolve through the @let@ bindings of the expression being
    rewritten (a @bind@ specialised to a dictionary parameter, as in
    polymorphic code, stays a @let@-local). Names are unique within one
    expression after 'renameShadowedNames', so a flat scan is unambiguous.
-}
mkResolve ∷ Map QName Exp → Exp → Qualified Name → Maybe Exp
mkResolve topLevel expr = \case
  Imported m n → Map.lookup (QName m n) topLevel
  Local n → Map.lookup n letLocals
 where
  -- All let-binding group members, not only 'Standalone' ones, so a local alias
  -- bound in a recursive @let@ group still resolves (see 'topLevel').
  letLocals ∷ Map Name Exp
  letLocals =
    Map.fromList
      [ (name, def)
      | sub ← universeOf subexpressions expr
      , Let _ binds _ ← [sub]
      , grouping ← toList binds
      , (_ann, name, def) ← toList grouping
      ]

--------------------------------------------------------------------------------
-- Rewrite rule ----------------------------------------------------------------

flattenRule ∷ (Qualified Name → Maybe Exp) → RewriteRuleM (State Int) Ann
flattenRule resolve expr =
  case peelChain resolve expr of
    (steps, finalAction)
      | length steps > threshold →
          maybe NoChange (Rewritten Recurse)
            <$> lambdaLift steps finalAction
    _ → pure NoChange

{- | One recognised step of a bind chain: @bind action (\param -> …)@. Fields:
the bind head, the continuation parameter, and the action — all kept verbatim
(only the continuation /structure/ is rewritten).
-}
data Step = Step Exp (Parameter Ann) Exp

{- | Peel a maximal prefix of recognised bind steps, returning them together
with the first expression that is not a step (the chain's final action). An
empty step list means @expr@ is not a chain head and is left untouched.
-}
peelChain ∷ (Qualified Name → Maybe Exp) → Exp → ([Step], Exp)
peelChain resolve = go
 where
  go expr = case asStep resolve expr of
    Just (step, rest) → first (step :) (go rest)
    Nothing → ([], expr)

{- | Recognise @bind action (\param -> rest)@ as a step plus its continuation
body, when @bind@ resolves to a (non-Effect\/ST) monadic bind. A statement-only
@do@ line is a @discard action (\_ -> rest)@ with the same shape; it is
recognised too (see 'isBindHead'), so an interleaved statement does not break a
chain into sub-threshold fragments.
-}
asStep ∷ (Qualified Name → Maybe Exp) → Exp → Maybe (Step, Exp)
asStep resolve expr = case spine expr of
  (hd, [action, k])
    | isBindHead resolve hd
    , Abs _ann param rest ← k →
        Just (Step hd param action, rest)
  _ → Nothing

--------------------------------------------------------------------------------
-- Lambda-lifting --------------------------------------------------------------

{- | Lambda-lift a recognised chain into a flat @let@ of @$kontN@ helpers.
Returns 'Nothing' (bail, leave the chain nested) when the forwarded live set at
some cut exceeds the upvalue budget.
-}
lambdaLift ∷ [Step] → Exp → State Int (Maybe Exp)
lambdaLift steps finalAction =
  -- Build bottom-up: the deepest segment carries the final action; each
  -- shallower segment ends by calling the helper wrapping the one below it.
  -- @reverse segments@ is deepest-first, so its head is the deepest segment and
  -- its tail are the upper segments in the order the fold needs (a segment is
  -- processed only after the helper it calls has been built).
  case reverse (chunksOf segmentSize steps) of
    [] → pure Nothing
    deepestSeg : upperDeepFirst → do
      let deepest = buildSteps deepestSeg finalAction
      (body1, konts) ← foldlM cut (deepest, []) upperDeepFirst
      let maxLive = foldl' max 0 (map fst konts)
      pure
        if null konts || maxLive > maxLiveSet
          then Nothing
          -- @konts@ accumulates deepest-first via prepend, so it ends up
          -- shallowest-first; reverse so the deepest helper is defined first
          -- (a helper only references already-defined ones).
          else Just (letHelpers (reverse (map snd konts)) body1)
 where
  -- Position of each named binder in the chain, for a stable parameter order.
  bindOrder ∷ Map Name Int
  bindOrder =
    Map.fromList
      [ (name, i)
      | (i, Step _ (ParamNamed _ name) _) ← zip [0 ..] steps
      ]
  chainBound ∷ Set Name
  chainBound = Map.keysSet bindOrder

  -- The earlier-bound chain variables a helper body still references, in
  -- binding order: exactly the parameters the helper must take and the call
  -- site must forward. Computed from the built body, so a @$kontN@ call's
  -- variable arguments propagate the live set transitively across helpers.
  liveVars ∷ Exp → [Name]
  liveVars body =
    List.sortOn
      (\n → Map.findWithDefault maxBound n bindOrder)
      [ n
      | Local n ← Map.keys (countFreeRefs body)
      , Set.member n chainBound
      ]

  -- Turn the current deepest body into a named helper and prepend a segment
  -- whose tail calls it.
  cut
    ∷ (Exp, [(Int, Grouping (Ann, Name, Exp))])
    → [Step]
    → State Int (Exp, [(Int, Grouping (Ann, Name, Exp))])
  cut (deepBody, konts) seg = do
    kname ← freshKontName
    let params = liveVars deepBody
        helperDef = curryAbs params deepBody
        helper = Standalone (noAnn, kname, helperDef)
        callTail = applyToVars (refLocal0 kname) params
        body = buildSteps seg callTail
    pure (body, (length params, helper) : konts)

-- | Rebuild a segment's nested @bind action (\param -> …)@ wrapping a tail.
buildSteps ∷ [Step] → Exp → Exp
buildSteps steps tailExp =
  foldr step tailExp steps
 where
  step ∷ Step → Exp → Exp
  step (Step hd param action) rest =
    App noAnn (App noAnn hd action) (Abs noAnn param rest)

-- | @\\p1 -> \\p2 -> … -> body@ (p1 outermost).
curryAbs ∷ [Name] → Exp → Exp
curryAbs params body =
  foldr (Abs noAnn . ParamNamed noAnn) body params

-- | @f p1 p2 …@, applying the variables in the same order as 'curryAbs'.
applyToVars ∷ Exp → [Name] → Exp
applyToVars = foldl' \f p → App noAnn f (refLocal0 p)

letHelpers ∷ [Grouping (Ann, Name, Exp)] → Exp → Exp
letHelpers [] body = body
letHelpers (h : hs) body = Let noAnn (h :| hs) body

--------------------------------------------------------------------------------
-- Recognising a bind head -----------------------------------------------------

{- | Does this chain-head expression denote a monadic @bind@ (or a @bind@-shaped
@discard@)? Two recognisers, because the optimizer leaves bind heads in two very
different shapes:

  * A plain instance (e.g. @Maybe@): the head is @dict.bind@ where @dict@ is a
    'Control.Bind.Bind' dictionary literal, carrying a @bind@ method and its
    @Apply0@ superclass field. We inspect the dictionary's fields directly, via
    'peelAlias' + 'isBindDict' — /without/ reducing into the @bind@ method.

  * A polymorphic or monad-transformer bind: the head reduces — through aliases,
    a literal-dictionary field projection, and beta — to @Control.Bind.bind
    <dict>@. A statement-only @do@ line (@discard@) reduces here too: the
    @Discard Unit@ instance defines @discard = bind@, and the optimizer leaves
    the head as @(dict.discard) dictInner@. Recognising it is what stops a
    statement from splitting a chain into sub-'threshold' fragments (e.g. a
    @State@ block of @get@\/@put@, where every other step is a @put@).
    'headReducesToBind' does this, stopping at the @Control.Bind@ /names/ rather
    than resolving through them — after linking they are themselves top-level
    bindings, so resolving would step into @\\dict -> dict.bind@ and lose track.

Effect\/ST are not excluded here: 'magicDo' has already consumed their chains
(see the module header).
-}
isBindHead ∷ (Qualified Name → Maybe Exp) → Exp → Bool
isBindHead resolve hd =
  bindDictHead || headReducesToBind resolve hd
 where
  bindDictHead = case peelAlias resolve hd of
    ObjectProp _ann obj (PropName "bind") → isBindDict resolve obj
    _ → False

{- | Reduce an application spine just far enough to decide whether its head is
@Control.Bind.bind@ (or a @Control.Bind.discard@ of the @Discard Unit@ instance,
which /is/ @bind@). Each reduction step — resolve a 'Ref' alias, project a field
out of a literal dictionary, beta-reduce a redex — is tried only /after/ checking
the head against the known @Control.Bind@ names, so those names act as stops even
though linking makes them resolvable. Bounded by 'maxHops'.
-}
headReducesToBind ∷ (Qualified Name → Maybe Exp) → Exp → Bool
headReducesToBind resolve = go maxHops . spine
 where
  go ∷ Int → (Exp, [Exp]) → Bool
  go fuel (h, args)
    | fuel <= 0 = False
    | otherwise = case (h, args) of
        -- @bind <dict> …@: any monad's bind.
        (Ref _ann (Imported m n) _, _dict : _)
          | (m, n) == controlBindBind → True
        -- @discard discardUnit <dict> …@: a not-yet-collapsed statement line.
        (Ref _ann (Imported m n) _, dictD : _)
          | (m, n) == controlBindDiscard
          , denotes resolve controlBindDiscardUnit dictD →
              True
        -- Otherwise reduce the head one step and retry.
        (Ref _ann qname _, _)
          | Just def ← resolve qname → go (fuel - 1) (reSpine def args)
        (ObjectProp _ann (LiteralObject _ann' fields) prop, _)
          | Just value ← List.lookup prop fields →
              go (fuel - 1) (reSpine value args)
        (Abs _ann (ParamNamed _ p) body, arg : rest') →
          go (fuel - 1) $
            reSpine (unshift p 0 (substitute (Local p) 0 arg body)) rest'
        (Abs _ann (ParamUnused _) body, _ : rest') →
          go (fuel - 1) (reSpine body rest')
        _ → False

  -- Re-attach trailing arguments after reducing the head.
  reSpine ∷ Exp → [Exp] → (Exp, [Exp])
  reSpine e extra = let (h, a) = spine e in (h, a <> extra)

{- | Does the expression ultimately refer to the given imported name, possibly
through module-local aliases? The name is checked /before/ resolving, so a name
that is itself a top-level binding still matches. Bounded by 'maxHops'.
-}
denotes ∷ (Qualified Name → Maybe Exp) → (ModuleName, Name) → Exp → Bool
denotes resolve (tm, tn) = go maxHops
 where
  go ∷ Int → Exp → Bool
  go fuel = \case
    Ref _ann q@(Imported m n) _
      | m == tm, n == tn → True
      | fuel > 0, Just def ← resolve q → go (fuel - 1) def
    Ref _ann q@(Local _) _
      | fuel > 0, Just def ← resolve q → go (fuel - 1) def
    _ → False

-- | A 'Control.Bind.Bind' dictionary literal: a record with @bind@ and @Apply0@.
isBindDict ∷ (Qualified Name → Maybe Exp) → Exp → Bool
isBindDict resolve obj = case peelAlias resolve obj of
  LiteralObject _ann fields →
    hasField (PropName "bind") fields && hasField (PropName "Apply0") fields
  _ → False
 where
  hasField ∷ PropName → [(PropName, Exp)] → Bool
  hasField p = any ((== p) . fst)

controlBindBind, controlBindDiscard, controlBindDiscardUnit ∷ (ModuleName, Name)
controlBindBind = (ModuleName "Control.Bind", Name "bind")
controlBindDiscard = (ModuleName "Control.Bind", Name "discard")
controlBindDiscardUnit = (ModuleName "Control.Bind", Name "discardUnit")

{- | Follow @Ref → definition@ aliases (bounded, to stay terminating on
recursive bindings) to the underlying expression.
-}
peelAlias ∷ (Qualified Name → Maybe Exp) → Exp → Exp
peelAlias resolve = go maxHops
 where
  go ∷ Int → Exp → Exp
  go fuel = \case
    Ref _ann qname _idx
      | fuel > 0, Just def ← resolve qname → go (fuel - 1) def
    other → other

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

-- | Unwind an application into its head and arguments (left to right).
spine ∷ Exp → (Exp, [Exp])
spine = go []
 where
  go ∷ [Exp] → Exp → (Exp, [Exp])
  go acc (App _ann f a) = go (a : acc) f
  go acc h = (h, acc)

refLocal0 ∷ Name → Exp
refLocal0 name = Ref noAnn (Local name) (Index 0)

freshKontName ∷ State Int Name
freshKontName = state \n → (Name ("$kont" <> show n), n + 1)

chunksOf ∷ Int → [a] → [[a]]
chunksOf _ [] = []
chunksOf n xs = let (h, t) = splitAt n xs in h : chunksOf n t

--------------------------------------------------------------------------------
-- Tunables --------------------------------------------------------------------

{- | Only fire on chains longer than this. Short chains are below Lua's nesting
cap and are left untouched, so existing goldens do not churn. Must exceed
'segmentSize' so the helper\/body segments produced by a fire never re-fire
(which guarantees termination of the 'Recurse' rewrite).
-}
threshold ∷ Int
threshold = 50

{- | Steps per segment. Each step is a few Lua nesting levels, so this caps a
helper body's nesting well under @LUAI_MAXCCALLS@ (~200). Kept below 'threshold'
(see above). Calibrated against the generated golden's measured nesting.
-}
segmentSize ∷ Int
segmentSize = 40

{- | Bail when a helper's forwarded live set exceeds this. The innermost closure
of a segment captures roughly @segmentSize + liveSet@ upvalues, and Lua 5.1 caps
a function at 60 upvalues (@LUAI_MAXUPVALUES@).
-}
maxLiveSet ∷ Int
maxLiveSet = 15

-- | Bound on alias resolution, matching 'Language.PureScript.Backend.IR.MagicDo'.
maxHops ∷ Int
maxHops = 64
