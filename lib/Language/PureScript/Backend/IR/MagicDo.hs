{- | Magic-do: flatten straight-line Effect/ST @do@ blocks into one thunk.

A @do@ block desugars to a chain of 'Control.Bind.bind' / 'Control.Bind.discard'
applications whose continuations are lexically nested lambdas:

>   bind bindEffect m1 (\x -> discard discardUnit bindEffect m2 (\_ -> … last))

A long enough chain exceeds Lua's parser nesting limit (@LUAI_MAXCCALLS@, ≈200),
so the generated file fails to load with @chunk has too many syntax levels@
(issue #46). Because the 'Effect' and 'ST' monads represent a computation as a
nullary thunk (@function() … end@, run by calling it), we can recognise their
@bind@/@discard@ and rewrite the whole chain into a flat statement sequence:

>   function() local x = m1(); local _ = m2(); …; return last() end

which is flat regardless of length. This mirrors the magic-do pass of the
upstream JS backend and @purs-backend-es@.

== Why a rewrite into existing 'Let'\/'Abs', not a new IR node

The flattened shape reuses 'Let' (whose code generator already emits a flat
sequence of @local@ statements, see Note [Sequential scoping of Let bindings])
wrapped in a nullary 'Abs' (the thunk). Adding a dedicated effect node would
ripple through every traversal over 'RawExp' for no benefit here, since the
goal is purely to flatten.

== Why this runs last (the final step of 'optimizedUberModule')

  * Earlier, dead-code elimination would delete the @local _ =@ bindings
    introduced for 'discard': their names are unreferenced, so DCE sees them as
    dead and would silently drop the effect.

  * Every local is uniquely named under GUC (established by 'uniquifyNames'
    at the front of the pipeline and preserved throughout), so moving a
    binder out of a lambda and into a 'Let' needs no accompanying
    substitution — only the name travels.

Running it as the last step of 'optimizedUberModule' (rather than at each call
site) means both the compiler and the golden-test harness pick it up from the
single pipeline definition.

Only 'Effect' and 'ST' are flattened — their value is a thunk, so @bind m k@
means "run @m@, then run @k@ of the result". Other monads keep their @bind@
calls; the generic deeply-nested case (issue #104) is handled by the
'Language.PureScript.Backend.IR.FlattenDeepBinds' pass, which runs right after
this one and lambda-lifts whatever bind chains remain.
-}
module Language.PureScript.Backend.IR.MagicDo (magicDo) where

import Data.List qualified as List
import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , QName (..)
  , Qualified (..)
  , discardName
  )
import Language.PureScript.Backend.IR.Supply (SupplyM)
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Binding
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , RewriteRuleM
  , noAnn
  , rewriteExpTopDownM
  , substituteMoveM
  , pattern Abs
  , pattern App
  )

-- | Flatten Effect/ST @do@ blocks in every binding and export of the module.
magicDo ∷ UberModule → SupplyM UberModule
magicDo uber@UberModule {uberModuleBindings, uberModuleExports} = do
  uberModuleBindings' ←
    traverse (traverse (traverse rewrite)) uberModuleBindings
  uberModuleExports' ← traverse (traverse rewrite) uberModuleExports
  pure
    uber
      { uberModuleBindings = uberModuleBindings'
      , uberModuleExports = uberModuleExports'
      }
 where
  -- Top-down deliberately: a chain must be consumed from its outermost
  -- head (every tail of a chain is itself a chain head, so a bottom-up
  -- driver would rewrite the tails first, nesting one thunk per step
  -- and defeating the flattening). See 'rewriteExpTopDownM'.
  rewrite ∷ Exp → SupplyM Exp
  rewrite = rewriteExpTopDownM (magicDoRule resolve)

  -- Top-level bindings, so that a @bind@/@discard@ floated into a module-local
  -- alias (e.g. @Module.discard = discard discardUnit bindEffect@) can be
  -- resolved back to the instance it was specialised to.
  resolve ∷ QName → Maybe Exp
  resolve = (`Map.lookup` topLevel)

  topLevel ∷ Map QName Exp
  topLevel =
    Map.fromList [(qname, expr) | Standalone (qname, expr) ← uberModuleBindings]

--------------------------------------------------------------------------------
-- Rewrite rule ----------------------------------------------------------------

magicDoRule ∷ (QName → Maybe Exp) → RewriteRuleM SupplyM Ann
magicDoRule resolve expr = do
  (statements, finalAction) ← peelChain resolve expr
  pure case statements of
    [] → Nothing
    _ → Just (buildThunk statements finalAction)

{- | Wrap the flattened statements and final action into an Effect/ST thunk.

The statements are split into chunks of at most 'chunkSize', each chunk a
nested thunk that runs its locals and then runs the next chunk. This keeps both
Lua 5.1 limits in check: a flat thunk would overflow @LUAI_MAXVARS@ (≈200 local
variables per function) on a long block, while the original nesting overflowed
@LUAI_MAXCCALLS@ (≈200 syntactic nesting levels). Chunking caps locals per
function at 'chunkSize' and nesting depth at @ceil(n / chunkSize)@.
-}
buildThunk ∷ [Binding] → Exp → Exp
buildThunk statements finalAction = thunk (go (chunksOf chunkSize statements))
 where
  go ∷ [[Binding]] → Exp
  go [] = runEffect finalAction
  go [lastChunk] = Let noAnn (NE.fromList lastChunk) (runEffect finalAction)
  go (chunk : chunks) =
    Let noAnn (NE.fromList chunk) (runEffect (thunk (go chunks)))

  thunk ∷ Exp → Exp
  thunk = Abs noAnn (ParamUnused noAnn)

{- | At most this many @local@ bindings per generated function, to stay under
Lua 5.1's @LUAI_MAXVARS@ (200).
-}
chunkSize ∷ Int
chunkSize = 150

chunksOf ∷ Int → [a] → [[a]]
chunksOf _ [] = []
chunksOf n xs = let (h, t) = splitAt n xs in h : chunksOf n t

{- | Peel a chain of Effect/ST @bind@/@discard@ nodes into the leading
statements plus the final action (the first expression that is not such a
node). Returns no statements when the expression is not a recognised chain head,
which leaves it untouched.
-}
peelChain ∷ (QName → Maybe Exp) → Exp → SupplyM ([Binding], Exp)
peelChain resolve = go
 where
  go expr =
    classify resolve expr >>= \case
      Just (BindNode name action rest) →
        first (statement name action :) <$> go rest
      Just (DiscardNode action rest) →
        first (statement discardName action :) <$> go rest
      Nothing →
        pure ([], expr)

  statement ∷ Name → Exp → Binding
  statement name action = Standalone (noAnn, name, runEffect action)

--------------------------------------------------------------------------------
-- Recognising Effect/ST bind/discard ------------------------------------------

-- | One step of an Effect/ST @do@ chain.
data Node
  = -- | @x <- m; rest@
    BindNode Name Exp Exp
  | -- | @m; rest@
    DiscardNode Exp Exp

{- | Recognise one node of an Effect/ST @do@ chain.

The optimizer specialises and inlines @bind@\/@discard@, so the chain head is
rarely a bare @Control.Bind.bind@ reference. Instead it is a module-local alias
whose definition reduces, through record-field access and beta, to
@bind bindEffect@ (the @Discard Unit@ instance defines @discard = bind@). We
therefore normalise the application head one reduction at a time — resolving
aliases, projecting fields out of literal dictionaries, and beta-reducing — and
match once it is exposed as @bind dict action continuation@.
-}
classify ∷ (QName → Maybe Exp) → Exp → SupplyM (Maybe Node)
classify resolve = go maxHops . spine
 where
  go ∷ Int → (Exp, [Exp]) → SupplyM (Maybe Node)
  go fuel (hd, args)
    | fuel <= 0 = pure Nothing
    | otherwise = case (hd, args) of
        -- Normalised form: bind dict action (\param -> rest). A 'discard' has
        -- already collapsed to this because `discardUnit.discard = bind`.
        (Ref _ (Imported m n), [dict, action, k])
          | (m, n) == bindName
          , isBindDict resolve dict →
              pure case k of
                Abs _ (ParamNamed _ name) rest → Just (BindNode name action rest)
                Abs _ (ParamUnused _) rest → Just (DiscardNode action rest)
                _ → Nothing
        -- Discard not yet inlined to its instance method.
        (Ref _ (Imported m n), [dictD, dictB, action, k])
          | (m, n) == discardName'
          , denotes resolve discardUnit dictD
          , isBindDict resolve dictB
          , Abs _ (ParamUnused _) rest ← k →
              pure (Just (DiscardNode action rest))
        -- Otherwise reduce the head one step and retry.
        (Ref _ (Imported m n), _)
          | Just def ← resolve (QName m n) →
              go (fuel - 1) (reSpine def args)
        (ObjectProp _ (LiteralObject _ fields) prop, _)
          | Just value ← List.lookup prop fields →
              go (fuel - 1) (reSpine value args)
        (Abs _ (ParamNamed _ p) body, arg : rest') → do
          -- Speculative beta while classifying: the λ is consumed here and
          -- never re-emitted on failure, so the first occurrence may keep
          -- its binder names ('substituteMoveM'). A failed match still
          -- burns supply names on the discarded reduction — deterministic,
          -- and accepted (see the module haddock).
          reduced ← substituteMoveM (Local p) arg body
          go (fuel - 1) (reSpine reduced rest')
        (Abs _ (ParamUnused _) body, _ : rest') →
          go (fuel - 1) (reSpine body rest')
        _ → pure Nothing

  -- Re-attach trailing arguments after a head reduction.
  reSpine ∷ Exp → [Exp] → (Exp, [Exp])
  reSpine hd' extra = let (h, a) = spine hd' in (h, a <> extra)

{- | Does the expression ultimately denote the given instance, possibly through
module-local aliases?
-}
denotes ∷ (QName → Maybe Exp) → (ModuleName, Name) → Exp → Bool
denotes resolve target = go maxHops
 where
  go ∷ Int → Exp → Bool
  go fuel = \case
    Ref _ (Imported m n)
      | (m, n) == target → True
      | fuel > 0, Just def ← resolve (QName m n) → go (fuel - 1) def
    _ → False

isBindDict ∷ (QName → Maybe Exp) → Exp → Bool
isBindDict resolve dict =
  denotes resolve bindEffect dict || denotes resolve bindST dict

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

-- | Unwind an application into its head and arguments (left to right).
spine ∷ Exp → (Exp, [Exp])
spine = go []
 where
  go ∷ [Exp] → Exp → (Exp, [Exp])
  go acc (App _ f a) = go (a : acc) f
  go acc h = (h, acc)

{- | Run an Effect/ST computation: apply the thunk to no arguments. The
synthetic @Prim.undefined@ argument is erased to an empty argument list by
the Lua code generator, so this emits @m()@.
-}
runEffect ∷ Exp → Exp
runEffect m =
  App noAnn m (Ref noAnn (Imported (ModuleName "Prim") (Name "undefined")))

{- | Bound on alias/instance resolution to stay terminating on recursive
bindings.
-}
maxHops ∷ Int
maxHops = 64

bindName ∷ (ModuleName, Name)
bindName = (ModuleName "Control.Bind", Name "bind")

discardName' ∷ (ModuleName, Name)
discardName' = (ModuleName "Control.Bind", Name "discard")

discardUnit ∷ (ModuleName, Name)
discardUnit = (ModuleName "Control.Bind", Name "discardUnit")

bindEffect ∷ (ModuleName, Name)
bindEffect = (ModuleName "Effect", Name "bindEffect")

bindST ∷ (ModuleName, Name)
bindST = (ModuleName "Control.Monad.ST.Internal", Name "bindST")
