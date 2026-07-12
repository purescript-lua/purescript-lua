{- | Magic-do: flatten straight-line Effect/ST @do@ blocks into one thunk.

A @do@ block desugars to a chain of 'Control.Bind.bind' / 'Control.Bind.discard'
applications whose continuations are lexically nested lambdas. By the time this
pass runs, the canonicalization of Note [Canonical Effect/ST heads] has rewritten
every Effect/ST dictionary application into an application of the real foreign
method, so the chain reads:

>   bindE m1 (\x -> bindE m2 (\_ -> … last))

A long enough chain exceeds Lua's parser nesting limit (@LUAI_MAXCCALLS@, ≈200),
so the generated file fails to load with @chunk has too many syntax levels@
(issue #46). Because the 'Effect' and 'ST' monads represent a computation as a
nullary thunk (@function() … end@, run by calling it), we can recognise their
@bind@/@discard@ and rewrite the whole chain into a flat statement sequence:

>   function() local x = m1(); local _ = m2(); …; return last() end

which is flat regardless of length. This is the classic magic-do
transformation of PureScript backends.

== Recognition is by qualified name

A chain step is @head action continuation@ where the head denotes a canonical
bind ('canonicalBindNames', issue #182). Three head forms occur:

  1. a direct reference to the canonical foreign (@Effect.bindE@,
     @Control.Monad.ST.Internal.bind_@);
  2. the dissolved foreign-accessor read — the common form here: the linker
     binds a foreign as a field read off its module's @foreign@ table
     ('foreignAccessorQName'), and the optimizer dissolves that binding into
     its use sites;
  3. a top-level alias one hop away from either (an @inline always@ directive
     can pin such an alias undissolved).

Name matching needs no fuel, no alias chasing and no speculative
beta-reduction, so the pass is pure — it draws no supply names.

== The pure run peephole

Running a canonical @pure@ is the identity on its argument: @pureE(x)()@
evaluates @x@ at exactly the program point where the run happens, so
@App (pure x) EffectRunArg@ rewrites to @x@. This collapses the
@pure@-terminated chain tails and mid-chain @x <- pure e@ statements this pass
itself emits (the top-down driver revisits rewritten output), and the
pre-existing runs of the foreign lifter's @run*Fn@ wrappers. A collapsed
statement @local x = e@ is no longer an effect run, so dead-code elimination
may later drop it when @x@ is unreferenced — sound, since @e@ is pure. Note:
a standalone @pureE x@ (no run) must NOT rewrite to a thunk @\_ -> x@; that
would move @x@'s evaluation from construction time to run time.

== Why a rewrite into existing 'Let'\/'Abs', not a new IR node

The flattened shape reuses 'Let' (whose code generator already emits a flat
sequence of @local@ statements, see Note [Sequential scoping of Let bindings])
wrapped in a nullary 'Abs' (the thunk). Adding a dedicated effect node would
ripple through every traversal over 'RawExp' for no benefit here, since the
goal is purely to flatten.

== Why this runs late in 'optimizedUberModule'

  * The pass needs the canonical heads exposed at the use sites, which the
    optimize fixpoints produce (dissolving the linker's accessor bindings into
    the chains).

  * Every local is uniquely named under GUC (established by 'uniquifyNames'
    at the front of the pipeline and preserved throughout), so moving a
    binder out of a lambda and into a 'Let' needs no accompanying
    substitution — only the name travels.

The @local _ =@ statements introduced for 'discard' survive the passes that
follow: their right-hand sides are effect runs, which dead-code elimination
keeps even though the binder is unreferenced (see 'isEffectRun').

Running it inside 'optimizedUberModule' (rather than at each call site) means
both the compiler and the golden-test harness pick it up from the single
pipeline definition.

Only 'Effect' and 'ST' are flattened — their value is a thunk, so @bind m k@
means "run @m@, then run @k@ of the result". Other monads keep their @bind@
calls; the generic deeply-nested case (issue #104) is handled by the
'Language.PureScript.Backend.IR.FlattenDeepBinds' pass, which runs right after
this one and lambda-lifts whatever bind chains remain.
-}
module Language.PureScript.Backend.IR.MagicDo (magicDo) where

import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.EffectNames
  ( canonicalBindNames
  , canonicalPureNames
  )
import Language.PureScript.Backend.IR.Linker
  ( UberModule (..)
  , foreignAccessorQName
  )
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , Qualified (..)
  , discardName
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Binding
  , Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , RewriteRule
  , noAnn
  , rewriteExpTopDown
  , pattern Abs
  , pattern App
  , pattern EffectRunArg
  )

-- | Flatten Effect/ST @do@ blocks in every binding and export of the module.
magicDo ∷ UberModule → UberModule
magicDo uber@UberModule {uberModuleBindings, uberModuleExports} =
  uber
    { uberModuleBindings = fmap rewrite <<$>> uberModuleBindings
    , uberModuleExports = fmap rewrite <$> uberModuleExports
    }
 where
  -- Top-down deliberately: a chain must be consumed from its outermost
  -- head (every tail of a chain is itself a chain head, so a bottom-up
  -- driver would rewrite the tails first, nesting one thunk per step
  -- and defeating the flattening). See 'rewriteExpTopDown'.
  rewrite ∷ Exp → Exp
  rewrite = rewriteExpTopDown (magicDoRule resolve)

  -- Top-level bindings, so that a chain head referencing a module-local
  -- alias of a canonical name (e.g. one pinned by @inline always@) can
  -- be resolved one hop back to it.
  resolve ∷ QName → Maybe Exp
  resolve = (`Map.lookup` topLevel)

  topLevel ∷ Map QName Exp
  topLevel =
    Map.fromList [(qname, expr) | Standalone (qname, expr) ← uberModuleBindings]

--------------------------------------------------------------------------------
-- Rewrite rule ----------------------------------------------------------------

magicDoRule ∷ (QName → Maybe Exp) → RewriteRule Ann
magicDoRule resolve expr
  -- The pure run peephole (see the module haddock): running a canonical
  -- pure is the identity on its argument.
  | App _ (App _ pureHead x) (EffectRunArg _) ← expr
  , isCanonicalHead canonicalPureNames resolve pureHead =
      Just x
  | otherwise = case peelChain resolve expr of
      ([], _) → Nothing
      (statements, finalAction) → Just (buildThunk statements finalAction)

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
peelChain ∷ (QName → Maybe Exp) → Exp → ([Binding], Exp)
peelChain resolve = go
 where
  go ∷ Exp → ([Binding], Exp)
  go expr = case classify resolve expr of
    Just (BindNode name action rest) →
      first (statement name action :) (go rest)
    Just (DiscardNode action rest) →
      first (statement discardName action :) (go rest)
    Nothing → ([], expr)

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

{- | Recognise one node of an Effect/ST @do@ chain:
@head action continuation@ where the head denotes a canonical bind
('canonicalBindNames' — a @discard@ has already collapsed to it, because
@discardUnit.discard = bind@; see Note [Canonical Effect/ST heads]) and
the continuation is a literal lambda.
-}
classify ∷ (QName → Maybe Exp) → Exp → Maybe Node
classify resolve = \case
  App _ (App _ hd action) k
    | isCanonicalHead canonicalBindNames resolve hd →
        case k of
          Abs _ (ParamNamed _ name) rest → Just (BindNode name action rest)
          Abs _ (ParamUnused _) rest → Just (DiscardNode action rest)
          _ → Nothing
  _ → Nothing

{- | Does the expression denote one of the given canonical names? Two
direct forms — a reference to the name, and the dissolved
foreign-accessor read of it ('foreignAccessorQName') — plus one hop
through a top-level alias whose right-hand side is either direct form
(see the module haddock).
-}
isCanonicalHead ∷ Set QName → (QName → Maybe Exp) → Exp → Bool
isCanonicalHead names resolve hd = case headQName hd of
  Nothing → False
  Just qname →
    Set.member qname names
      || maybe
        False
        (maybe False (`Set.member` names) . headQName)
        (resolve qname)

{- | The qualified name an imported reference or a dissolved
foreign-accessor read denotes.
-}
headQName ∷ Exp → Maybe QName
headQName = \case
  Ref _ (Imported modname name) → Just (QName modname name)
  expr → foreignAccessorQName expr

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

{- | Run an Effect/ST computation: apply the thunk to no arguments. The
synthetic 'EffectRunArg' argument is erased to an empty argument list by the Lua
code generator, so this emits @m()@. Unlike @Prim.undefined@ (the argument that
forces an ordinary nullary thunk), 'EffectRunArg' marks this application as an
effect run so 'isEffectRun' recognises it precisely (issue #180).
-}
runEffect ∷ Exp → Exp
runEffect m = App noAnn m (EffectRunArg noAnn)
