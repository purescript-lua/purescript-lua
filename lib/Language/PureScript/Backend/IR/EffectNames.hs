{- | The canonical names of the Effect/ST monad operations, and the
rewrite that produces them. See Note [Canonical Effect/ST heads].
-}
module Language.PureScript.Backend.IR.EffectNames
  ( canonicalBindNames
  , canonicalPureNames
  , canonicalizeEffectApp
  , canonicalizeEffectAppInModule
  ) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Names
  ( ModuleName (..)
  , Name (..)
  , QName (..)
  , Qualified (..)
  )
import Language.PureScript.Backend.IR.Types (RawExp (..), pattern App)

{- Note [Canonical Effect/ST heads]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Magic-do ("Language.PureScript.Backend.IR.MagicDo") flattens Effect/ST
@do@ chains, so it must recognise the chains' @bind@/@discard@/@pure@
steps. Recognising them by syntactic shape — unwinding application
spines, chasing aliases, projecting fields out of dictionary literals,
speculatively beta-reducing — is fragile: any optimizer rewrite that
changes a chain's shape silently starves the recognition, and a miss
falls back to thunk-nested closures that can overflow Lua's parser
nesting limit. Recognition is therefore by /qualified name/ (issue
#182): dictionary applications are rewritten early into applications of
the operations' real foreign methods, and magic-do matches those names.

The rewrite table ('canonicalizeEffectApp'):

  > bind    bindEffect                ==>  Effect.bindE
  > bind    bindST                    ==>  Control.Monad.ST.Internal.bind_
  > discard discardUnit bindEffect    ==>  Effect.bindE
  > discard discardUnit bindST       ==>  Control.Monad.ST.Internal.bind_
  > pure    applicativeEffect         ==>  Effect.pureE
  > pure    applicativeST             ==>  Control.Monad.ST.Internal.pure_

This is compile-time dictionary projection, semantically exact: the
instances define @bindEffect.bind = bindE@, @discardUnit.discard =
bind@, @applicativeEffect.pure = pureE@ (and the ST analogues), so each
row evaluates the same projection the runtime would. Partial
applications canonicalize too — purs CSE floats @discard discardUnit
bindEffect@ to the module top level as a bare dictionary application,
and the row matches it with no chain arguments present.

Why applications of the /real foreigns/, and not a synthetic marker or
an annotation:

  * A residual the consumer never lowers (a first-class @bind@ passed
    around as a value) remains executable at runtime — @bindE m k@ is
    already the program the dictionary application denoted.
  * 'Ann' annotations do not survive rewrites: a rule can rebuild a
    node without its annotation slot, which is why every inlining
    directive keys off a name rather than an annotation
    (Note [Inline annotations and inlining heuristics]), and why the
    'EffectRunArg' marker before this one is also a name, not an
    annotation.

The rewrite runs in two tiers, both required:

  1. At CoreFn translation ('Language.PureScript.Backend.IR.mkApplication'):
     applications are built bottom-up, so a nested pair canonicalizes at
     its innermost application and the enclosing builds compose. This
     covers cross-module uses and the CSE-float right-hand sides.
  2. As an optimizer rewrite rule
     ('Language.PureScript.Backend.IR.Optimizer.canonicalizeEffectHead'):
     inside its defining module a dictionary reference is 'Local' at
     translation time (e.g. @Control.Monad.ST.Internal@'s own float
     @bind = bind bindST@) and only becomes 'Imported' after the linker
     requalifies it, so tier 1 cannot see it. The rule also catches
     pairs exposed later by alias dissolution. It rewrites two nodes to
     one, so it is fixpoint-safe.

Both tiers match 'Imported' references only. A 'Local' reference has no
stable identity to match — the qualified name is the identity that
survives linking.

Tier 2 resolves head positions through top-level aliases (issue #297).
When a module instantiates @discard@ with two /different/ Bind
dictionaries — Effect or ST plus any second monad — purs's own CSE (the
CoreFn common-subexpression pass over compiler-synthesized dictionary
applications) floats the shared partial application as a binding of its
own:

  > discard  = Control.Bind.discard discardUnit
  > discard1 = discard bindST
  > discard2 = discard bindEffect

(A single-use instantiation may also stay applied inline in its chain —
@discard bindEffect m k@ — rather than becoming a float; the node shape
is the same.) Either way the row's head is hidden behind a module-local
alias that tier 1 cannot see (the reference is 'Local' at translation
time) and a plain structural match cannot either. Tier 2 therefore
matches each head position /through/ top-level aliases
('canonicalizeEffectAppInModule'):
a reference denotes a row's name if it is that name, or if the
top-level binding it names has a right-hand side that denotes it
(visited-bounded, so alias cycles cannot loop it). The dictionary
positions stay strict references — dictionaries are already top-level
constants, so CSE never hides them. The matched spines are structurally
bounded (@bind@/@pure@: two nodes, @discard@: three), so resolution
terminates after at most a hop per node.

Tier 2 also /declines/ a rewrite whose produced reference would dangle
(issue #297 again, the severe half): the canonical accessor bindings are
subject to dissolution and dead-code elimination like any other, so a
row exposed late — e.g. by alias dissolution after magic-do — may name
an accessor that no longer exists, and the manufactured reference would
compile to a read of a never-assigned module-table field (a nil call at
runtime). Declining is sound: the dictionary application left behind is
executable — @bindE m k@ is already the program the application
denotes. Tier 1 needs no such gate: it runs before linking, and the
linker includes the accessor bindings its references demand.

There is deliberately /no/ standalone @discard discardUnit ==> bind@
row: it would rewrite the discards of every monad, churning all the
non-Effect chains for zero benefit — only the Effect/ST rows feed a
consumer. @bindFlipped@/@=<<@ chains are likewise not recognised, same
as before this scheme (a non-goal, not a regression).

Consumers of the canonical names: magic-do matches chain heads against
'canonicalBindNames' and collapses @pure@ under effect runs via
'canonicalPureNames'.
-}

--------------------------------------------------------------------------------
-- Canonicalization ------------------------------------------------------------

{- | Tier 1 of Note [Canonical Effect/ST heads]: rewrite an Effect/ST
dictionary application into a reference to the real foreign method, per
the table in the note. Runs at CoreFn translation, where no top-level
aliases are visible (module-local references are still 'Local') and
every produced reference is safe — the linker includes the accessor
bindings the references demand. The produced reference keeps the outer
application's annotation. 'Nothing' when the node is not a row of the
table.
-}
canonicalizeEffectApp ∷ RawExp ann → Maybe (RawExp ann)
canonicalizeEffectApp = canonicalizeWith (const Nothing) (const True)

{- | Tier 2 of Note [Canonical Effect/ST heads]: like
'canonicalizeEffectApp', with the module's top-level bindings in scope.
Head positions match through top-level aliases (the purs CSE floats of
issue #297), and a rewrite is declined unless the module still binds
the canonical method the produced reference would name.
-}
canonicalizeEffectAppInModule
  ∷ Map QName (RawExp ann) → RawExp ann → Maybe (RawExp ann)
canonicalizeEffectAppInModule topLevel =
  canonicalizeWith (`Map.lookup` topLevel) (`Map.member` topLevel)

{- | The shared matcher: the first argument resolves a top-level alias
to its right-hand side, the second says whether a reference to the
given name may be manufactured. See Note [Canonical Effect/ST heads]
for both.
-}
canonicalizeWith
  ∷ ∀ ann
   . (QName → Maybe (RawExp ann))
  → (QName → Bool)
  → RawExp ann
  → Maybe (RawExp ann)
canonicalizeWith resolve live = \case
  App ann hd (Ref _ (Imported dm dn)) → do
    methods ← methodTable hd
    target ← Map.lookup (QName dm dn) methods
    guard (live target)
    pure (canonicalRef ann target)
  _ → Nothing
 where
  canonicalRef ∷ ann → QName → RawExp ann
  canonicalRef ann (QName m n) = Ref ann (Imported m n)

  -- The method table the head selects: bind/pure denoted directly or
  -- through aliases, or the discard·discardUnit pair — the pair itself
  -- possibly one alias, each of its positions possibly one more.
  methodTable ∷ RawExp ann → Maybe (Map QName QName)
  methodTable hd
    | denotes bindQName hd = Just bindMethods
    | denotes pureQName hd = Just pureMethods
    | Just (inner, unitArg) ← viewAppThroughAliases hd
    , denotes discardQName inner
    , denotes discardUnitQName unitArg =
        Just bindMethods
    | otherwise = Nothing

  -- Whether the expression denotes the given qualified name: it is a
  -- reference to it, or a reference to a top-level alias whose
  -- right-hand side denotes it. The visited set bounds alias chains.
  denotes ∷ QName → RawExp ann → Bool
  denotes target = go mempty
   where
    go ∷ Set QName → RawExp ann → Bool
    go visited = \case
      Ref _ (Imported m n)
        | QName m n == target → True
        | qname ← QName m n
        , Set.notMember qname visited
        , Just rhs ← resolve qname →
            go (Set.insert qname visited) rhs
      _ → False

  -- View an application node through top-level aliases: the node
  -- itself, or the application a chain of aliases resolves to.
  viewAppThroughAliases ∷ RawExp ann → Maybe (RawExp ann, RawExp ann)
  viewAppThroughAliases = go mempty
   where
    go ∷ Set QName → RawExp ann → Maybe (RawExp ann, RawExp ann)
    go visited = \case
      App _ f a → Just (f, a)
      Ref _ (Imported m n)
        | qname ← QName m n
        , Set.notMember qname visited
        , Just rhs ← resolve qname →
            go (Set.insert qname visited) rhs
      _ → Nothing

{- | The canonical Effect/ST bind methods: @Effect.bindE@ and
@Control.Monad.ST.Internal.bind_@.
-}
canonicalBindNames ∷ Set QName
canonicalBindNames = Set.fromList (Map.elems bindMethods)

{- | The canonical Effect/ST pure methods: @Effect.pureE@ and
@Control.Monad.ST.Internal.pure_@.
-}
canonicalPureNames ∷ Set QName
canonicalPureNames = Set.fromList (Map.elems pureMethods)

--------------------------------------------------------------------------------
-- Names -----------------------------------------------------------------------

bindQName, discardQName, discardUnitQName, pureQName ∷ QName
bindQName = QName (ModuleName "Control.Bind") (Name "bind")
discardQName = QName (ModuleName "Control.Bind") (Name "discard")
discardUnitQName = QName (ModuleName "Control.Bind") (Name "discardUnit")
pureQName = QName (ModuleName "Control.Applicative") (Name "pure")

effectModule, stModule ∷ ModuleName
effectModule = ModuleName "Effect"
stModule = ModuleName "Control.Monad.ST.Internal"

-- | Bind instance dictionaries mapped to their method foreigns.
bindMethods ∷ Map QName QName
bindMethods =
  Map.fromList
    [ (QName effectModule (Name "bindEffect"), QName effectModule (Name "bindE"))
    , (QName stModule (Name "bindST"), QName stModule (Name "bind_"))
    ]

-- | Applicative instance dictionaries mapped to their method foreigns.
pureMethods ∷ Map QName QName
pureMethods =
  Map.fromList
    [
      ( QName effectModule (Name "applicativeEffect")
      , QName effectModule (Name "pureE")
      )
    , (QName stModule (Name "applicativeST"), QName stModule (Name "pure_"))
    ]
