{- | The canonical names of the Effect/ST monad operations, and the
rewrite that produces them. See Note [Canonical Effect/ST heads].
-}
module Language.PureScript.Backend.IR.EffectNames
  ( canonicalBindNames
  , canonicalPureNames
  , canonicalizeEffectApp
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
     one, so it is fixpoint-safe, and the canonical heads are real
     foreigns, so firing after magic-do is harmless.

Both tiers match 'Imported' references only. A 'Local' reference has no
stable identity to match — the qualified name is the identity that
survives linking.

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

{- | Rewrite an Effect/ST dictionary application into an application of
the real foreign method, per the table in
Note [Canonical Effect/ST heads]. The produced reference keeps the
outer application's annotation. 'Nothing' when the node is not a row of
the table.
-}
canonicalizeEffectApp ∷ RawExp ann → Maybe (RawExp ann)
canonicalizeEffectApp = \case
  App ann (Ref _ (Imported hm hn)) (Ref _ (Imported dm dn))
    | QName hm hn == bindQName →
        canonicalRef ann <$> Map.lookup (QName dm dn) bindMethods
    | QName hm hn == pureQName →
        canonicalRef ann <$> Map.lookup (QName dm dn) pureMethods
  App
    ann
    (App _ (Ref _ (Imported hm hn)) (Ref _ (Imported um un)))
    (Ref _ (Imported dm dn))
      | QName hm hn == discardQName
      , QName um un == discardUnitQName →
          canonicalRef ann <$> Map.lookup (QName dm dn) bindMethods
  _ → Nothing
 where
  canonicalRef ∷ ann → QName → RawExp ann
  canonicalRef ann (QName m n) = Ref ann (Imported m n)

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
