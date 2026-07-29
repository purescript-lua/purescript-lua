{- | Absorb the magic-do thunk into an n-ary effect worker.

The uncurrying worker\/wrapper split
("Language.PureScript.Backend.IR.Uncurry") runs before magic-do
("Language.PureScript.Backend.IR.MagicDo"), so an effect function of two
or more /real/ arguments is already saturated at that arity when the
split measures it: the worker takes the real arguments, and its body —
the @do@ block — is what magic-do later rewrites into a nullary thunk.
Every fully applied statement site therefore compiles to two Lua calls
with a closure allocation between them:

>   local whileE$w = function(cond, act)
>     return function() … end            -- the thunk magic-do built
>   end
>   local _ = whileE$w(cond, act)()      -- allocate, then force

The late uncurry run cannot repair this. It splits manifest chains of
unary lambdas, and the worker is already an 'AbsN' whose thunk sits
/inside/ the body, so there is no chain left to re-split; that run only
absorbs the thunk parameter of the effect actions the early run left
alone (the unary ones, below its arity floor).

== The extension

A qualifying worker is extended in place: the thunk's parameter joins
the worker's parameter list and the thunk's body becomes the worker's
body.

>   w = AbsN [p₁…pₙ] (λ_. body)   ↦   w = AbsN [p₁…pₙ, _] body

Each forced site loses its outer call — @w(a₁…aₙ)(run)@ becomes
@w(a₁…aₙ, run)@, which is still an effect run by its trailing marker
('Language.PureScript.Backend.IR.Types.isEffectRun') and still one Lua
call, because the backend erases that marker from an n-ary argument
list. So the site above becomes @local _ = whileE$w(cond, act)@: one
call, no closure.

Each /wrapper/ — the curried delegate the split left under the original
name — grows by one parameter, which the delegate call passes on:

>   f = λf$p1.λf$p2. w(f$p1, f$p2)
>     ↦
>   f = λf$p1.λf$p2.λf$p2$t. w(f$p1, f$p2, f$p2$t)

A partial application @f a b@ therefore still evaluates to a closure —
the action — with the new innermost lambda playing the thunk's role,
and running it reaches the worker with the marker in place. The new
parameter is named after the wrapper's last one, which is unique within
its site, so the name is too, and it cannot collide with a source
identifier (no @$@ in PureScript identifiers).

== The precondition

The extension fires only for a worker that has at least one forced site
and whose every reference is either a forced site or a wrapper's
delegate call. Any other reference shape disqualifies it: the wider
arity would leave that site under-applied, and the backend drops the
worker's trailing unused parameter run, so an under-applied call is a
/saturated/ Lua call — it would run the effect at construction time
instead of returning the action. The shape that most often disqualifies
a binding is a worker call bound as an action value and run later,

>   local held = deferred$w("d", 4)   -- the action, not yet run
>   local _ = held()

where extending @deferred$w@ would make the first line run the effect.

== Scoping of the candidate maps

Top-level candidates live in one module-wide map: after
'Language.PureScript.Backend.IR.Linker.qualifyTopRefs' every reference
to a top-level binding is 'Imported' and QNames are globally unique, so
a reference in any binding or export can reach any of them. 'Let'-bound
candidates are collected, qualified and rewritten independently per
top-level site, because local binder names are unique only per site
(see "Language.PureScript.Backend.IR.Uniquify") — a disqualifying
reference in one site must not veto a same-named worker of another.

== Pipeline placement

Last, after the late uncurry run and the dead-code pass that follows it.
Nothing after this point moves a call, so the reference census is final;
and the wrappers whose sites all went to their workers are already
gone, so no doomed wrapper is grown. The pass creates no dead code — it
removes no reference — so nothing needs to run after it.
-}
module Language.PureScript.Backend.IR.AbsorbEffectThunk
  ( absorbEffectThunk
  ) where

import Control.Lens (cosmosOf, toListOf, transformOf)
import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , Qualified (..)
  , nameToText
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping
  , Parameter (..)
  , RawExp (..)
  , getAnn
  , listGrouping
  , noAnn
  , paramName
  , refLocal
  , setAnn
  , subexpressions
  , pattern Abs
  , pattern App
  , pattern EffectRunArg
  )
import Language.PureScript.Backend.IR.Uncurry (delegatesTo, manifestChain)

{- | Extend every qualifying effect worker by the parameter of the thunk
its body returns, rewriting the forced call sites into single n-ary
calls and growing the wrappers that delegate to it.
-}
absorbEffectThunk ∷ UberModule → UberModule
absorbEffectThunk uber@UberModule {..} =
  uber
    { uberModuleBindings = extendTop <<$>> processedBindings
    , uberModuleExports = second processSite <$> uberModuleExports
    }
 where
  -- Every expression a reference to a top-level candidate can occur in.
  siteExprs ∷ [Exp]
  siteExprs =
    (snd <$> (listGrouping =<< uberModuleBindings))
      <> (snd <$> uberModuleExports)

  topCandidates ∷ Map (Qualified Name) Int
  topCandidates =
    Map.fromList
      [ (Imported modname name, length params)
      | (QName modname name, expr) ← listGrouping =<< uberModuleBindings
      , Just (params, _thunkParam, _body) ← [thunkWorker expr]
      ]

  topExtended ∷ Map (Qualified Name) Int
  topExtended = qualified topCandidates siteExprs

  -- The call sites first, the worker definitions second: extending a
  -- worker changes its arity, which the site recognisers read off the
  -- pre-extension candidate map.
  processedBindings ∷ [Grouping (QName, Exp)]
  processedBindings = fmap (second processSite) <$> uberModuleBindings

  extendTop ∷ (QName, Exp) → (QName, Exp)
  extendTop (qname@(QName modname name), expr)
    | Imported modname name `Map.member` topExtended =
        (qname, extendWorker expr)
    | otherwise = (qname, expr)

  -- Process one top-level site: qualify its Let-bound candidates by
  -- their in-site references, then in one bottom-up sweep rewrite the
  -- forced sites, grow the wrappers, and extend the local workers.
  processSite ∷ Exp → Exp
  processSite expr = transformOf subexpressions step expr
   where
    localCandidates ∷ Map (Qualified Name) Int
    localCandidates =
      Map.fromList
        [ (Local name, length params)
        | Let _ann groupings _body ← toListOf (cosmosOf subexpressions) expr
        , (_memberAnn, name, rhs) ← listGrouping =<< toList groupings
        , Just (params, _thunkParam, _body) ← [thunkWorker rhs]
        ]

    extended ∷ Map (Qualified Name) Int
    extended = topExtended <> qualified localCandidates [expr]

    -- Bottom-up is safe because no rewrite produces a node another
    -- rewrite matches: a grown wrapper and an absorbed run both pass
    -- one argument more than the recognisers accept, and an extended
    -- local worker no longer returns a thunk. A wrapper is recognised
    -- at its chain root, so the bottom-up sweep reaches the delegate
    -- call inside it before the chain — and leaves it alone, since a
    -- delegate call is not a forced site.
    step ∷ Exp → Exp
    step e =
      fromMaybe e $
        (snd <$> forcedSite extended e)
          <|> (snd <$> wrapper extended e)
          <|> extendLocalWorkers extended e

    extendLocalWorkers ∷ Map (Qualified Name) Int → Exp → Maybe Exp
    extendLocalWorkers arities = \case
      Let ann groupings body
        | any isExtended (listGrouping =<< toList groupings) →
            Just (Let ann (fmap extend <$> groupings) body)
      _ → Nothing
     where
      isExtended (_ann, name, _rhs) = Local name `Map.member` arities
      extend member@(ann, name, rhs)
        | Local name `Map.member` arities = (ann, name, extendWorker rhs)
        | otherwise = member

--------------------------------------------------------------------------------
-- Recognition -----------------------------------------------------------------

{- | An n-ary worker whose body is a magic-do thunk: the worker's
parameters, the thunk's parameter and the thunk's body.

The arity floor of two is the uncurrying split's own: a /unary/ chain
ending in a thunk is a manifest two-deep chain, which the late uncurry
run splits and absorbs itself.
-}
thunkWorker ∷ Exp → Maybe (NonEmpty (Parameter Ann), Parameter Ann, Exp)
thunkWorker = \case
  AbsN _ann params (Abs _thunkAnn thunkParam@(ParamUnused _) body)
    | length params >= 2 → Just (params, thunkParam, body)
  _ → Nothing

{- | Move the thunk's parameter onto the worker's parameter list, the
thunk's body becoming the worker's body. The parameter stays a trailing
'ParamUnused' run (Note [n-ary abstraction]) because it is appended.
-}
extendWorker ∷ Exp → Exp
extendWorker expr = case thunkWorker expr of
  Just (params, thunkParam, body) →
    AbsN (getAnn expr) (params <> one thunkParam) body
  Nothing → expr

{- | A forced site — a saturated call to a candidate that an effect run
immediately forces — paired with the single n-ary call replacing it. The
run marker joins the argument list, so the site stays an effect run
('Language.PureScript.Backend.IR.Types.isEffectRun') and the Lua backend
still erases it.
-}
forcedSite
  ∷ Map (Qualified Name) Int → Exp → Maybe (Qualified Name, Exp)
forcedSite arities = \case
  App ann (AppN _callAnn (Ref _refAnn q) args) run@(EffectRunArg _)
    | Just arity ← Map.lookup q arities
    , length args == arity →
        Just (q, AppN ann (Ref noAnn q) (args <> one run))
  _ → Nothing

{- | A wrapper of a candidate — a manifest chain of named unary lambdas
whose body is the delegate call on the chain's own parameters — paired
with the chain grown by one parameter, which the delegate passes on.

Recognising and rewriting in one function keeps the reference census and
the rewrite from ever disagreeing about which references a wrapper
accounts for.
-}
wrapper ∷ Map (Qualified Name) Int → Exp → Maybe (Qualified Name, Exp)
wrapper arities expr = do
  (params, body) ← manifestChain expr
  (callAnn, refAnn, q, args) ← case body of
    AppN callAnn (Ref refAnn q) args → Just (callAnn, refAnn, q, args)
    _ → Nothing
  arity ← Map.lookup q arities
  guard (length params == arity)
  guard (delegatesTo q params body)
  thunkParam ← grownParam params
  let delegate =
        AppN callAnn (Ref refAnn q) (args <> one (refLocal thunkParam))
      grown = Abs noAnn (ParamNamed noAnn thunkParam) delegate
  pure (q, setAnn (getAnn expr) (foldr (Abs noAnn) grown (toList params)))

{- | The parameter a wrapper grows by, named after its last one — a name
unique within the site, so this one is too. 'Nothing' for an unnamed
last parameter, a shape 'delegatesTo' already rejects.
-}
grownParam ∷ NonEmpty (Parameter Ann) → Maybe Name
grownParam params = do
  name ← paramName (NE.last params)
  pure (Name (nameToText name <> "$t"))

{- | The candidates whose references the extension can rewrite in full:
at least one forced site, and no reference outside the forced sites and
the wrappers. See the module haddock's Precondition section for why any
other reference shape must veto the whole binding.
-}
qualified
  ∷ Map (Qualified Name) Int → [Exp] → Map (Qualified Name) Int
qualified candidates exprs = Map.filterWithKey accounted candidates
 where
  accounted ∷ Qualified Name → Int → Bool
  accounted q _arity =
    count forced q > 0
      && count refs q == count forced q + count wrappers q

  count ∷ Map (Qualified Name) Int → Qualified Name → Int
  count = flip (Map.findWithDefault 0)

  nodes ∷ [Exp]
  nodes = toListOf (cosmosOf subexpressions) =<< exprs

  refs, forced, wrappers ∷ Map (Qualified Name) Int
  refs = tally [q | Ref _ann q ← nodes]
  forced = tally (fst <$> mapMaybe (forcedSite candidates) nodes)
  wrappers = tally (fst <$> mapMaybe (wrapper candidates) nodes)

  tally ∷ [Qualified Name] → Map (Qualified Name) Int
  tally qs =
    Map.fromListWith (+) [(q, 1) | q ← qs, q `Map.member` candidates]
