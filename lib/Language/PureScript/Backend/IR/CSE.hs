{- | Conservative common-subexpression elimination (issue #183).

Optimization leaves verbatim repeats of pure subexpressions behind:
call-site inlining pastes the same method lambda at several sites of one
body, and a partially-applied paste leaves the same residual closure at
every site. Each repeat is a repeated allocation (a closure, a table)
or a repeated read at runtime. This pass hoists alpha-equivalent repeats
within one body into a shared 'Let' binding and replaces every
occurrence with a reference to it.

== The strictness caveat bounds the candidate classes

In a strict language, hoisting an expression that would only have
evaluated in one 'IfThenElse' branch into a dominating 'Let' evaluates
it on every path: divergence, exceptions, or effects would appear where
none existed. The pass therefore only touches forms that are effect-free
/by construction/ — evaluating them can at most allocate:

  * lambda literals ('AbsN') — closure allocation is pure;
  * non-empty array\/object literals whose elements are themselves
    effect-free values;
  * in-place 'Ctor' nodes (saturated by construction) whose field
    arguments are themselves effect-free values — a partial application
    is a runtime call of the curried wrapper and is left alone;
  * single reads over never-nil bases ('ObjectProp', 'ArrayIndex',
    'PrimLen', 'ReflectCtor', 'DataArgumentByIndex' over a 'Ref' or
    a record-read chain) — records and data values are write-once, so a
    read is stable, and a never-nil base makes it non-throwing (see
    'isRefProjection' for why a sum-variant slot is not such a base).
    Sharing a length read is what obliges 'PrimLen' to keep its operand
    immutable — see Note [PrimLen reads immutable values].

Never arbitrary applications: a call can do anything. GHC's CSE pass,
with its similar sharing restrictions, is the precedent. Sharing one
allocation where two existed is unobservable in well-typed PureScript —
the language exposes no reference equality on records, data values, or
functions (@unsafeRefEq@ is out of contract, as it is for GHC's CSE).

An extension recorded on the issue, deliberately not taken here: an
arbitrary pure expression can be hoisted when it is evaluated on every
path from the binding point (the downsafety condition from PRE), at the
cost of a very-busy-expressions analysis instead of this syntactic
guard.

== Blocks: repeats never share across a lambda boundary

Occurrences are grouped per /block/ — the body of one 'AbsN' (or a
top-level right-hand side), not crossing into nested 'AbsN' bodies. A
repeat under an inner lambda evaluates once per call of the /inner/
function; hoisting it to the enclosing body would allocate even when
that function is never called. Restricting a group to one block keeps
the enclosing function's work bounded by what it already did — the same
discipline that keeps
'Language.PureScript.Backend.IR.FloatIn' from sinking across an 'Abs',
mirrored: no work moves across a lambda in either direction. Within a
block, crossing an 'IfThenElse' arm is exactly the licensed move: the
candidate classes make eager evaluation unobservable.

== Scope: hoisting to the block top only

The shared binding lands at the top of the block, so a candidate whose
free references include a name bound /within/ the block (by a 'Let'
below the block top) is skipped: its right-hand side would not be in
scope at the binding point. Under GUC and well-scopedness the test is
exact: a free reference of an occurrence can only name an enclosing
binder, so intersecting the candidate's free locals with the set of all
names the block binds decides scope at the top. (Alpha-equivalent
occurrences have identical free references, so the group is checked
once.) Hoisting to the innermost dominating position instead would
catch repeats over 'Let'-bound values — a possible refinement, not
taken conservatively.

== The rewrite: one group per round, largest first

Each round canonicalizes every candidate in the block ('alphaKey':
annotations dropped, binders renamed positionally — the two dimensions
'Language.PureScript.Backend.IR.Types.alphaEq' ignores or freshening
varies), groups occurrences by the canonical form, and hoists the
largest eligible group: a fresh @$cse@ binding wraps the block, and
every occurrence — nested ones inside other candidates included —
becomes a reference. The next round re-analyzes the wrapped block, so a
group that only repeated /inside/ a hoisted group's occurrences is
recounted against the single surviving copy and hoisted only when it
still repeats. Largest-first makes the wrapping well-scoped by
construction: a later (smaller) group's occurrences can sit inside an
earlier binding's right-hand side, and the later 'Let' wraps /outside/
the earlier one, so the reference points outward.

Termination and idempotence: a hoisted group's canonical form survives
at exactly one place (the binding's right-hand side), so its count drops
below two; and replacing occurrences with a same-named fresh reference
cannot make two previously-distinct subexpressions alpha-equivalent —
had they differed only at replaced positions, they were already
equivalent. Rounds are therefore bounded by the number of groups, and a
converged block re-analyzes to no eligible groups at all.

== GUC

Requires and preserves the global-uniqueness condition (GUC =
@UniqueBinders@, issue #139): the kept copy is one of the original
occurrences (its binders stay unique — the deleted copies' binders are
gone), the minted @$cse@ names are supply-fresh, and 'alphaKey' resolves
references to binders by name, which GUC makes unambiguous.

== Pipeline placement

Runs once, between @share-accessors@ and @flattenDeepBinds@
('Language.PureScript.Backend.IR.Optimizer.optimizerPipeline'): after
the specialize fixpoint — the last pass that multiplies pure code — for
the same reason 'shareForeignAccessors' sits there, and after
@share-accessors@ itself, so foreign-accessor reads are already rebound
to top-level names instead of being grabbed per body here. It must not
join an optimize fixpoint: the Deref tier of @inlineLocalBindings@
pastes cheap projections at every use site, which would undo the
sharing each round.
-}
module Language.PureScript.Backend.IR.CSE
  ( eliminateCommonSubexpressions
  ) where

import Control.Lens (over, toListOf, traverseOf)
import Data.Map qualified as Map
import Data.Set qualified as Set
import Data.Traversable (mapAccumM)
import Language.PureScript.Backend.IR.Linker
  ( UberModule (..)
  , foreignAccessorQName
  )
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName
  , Qualified (Local)
  , discardName
  )
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName)
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , Parameter (..)
  , RawExp (..)
  , bindingNames
  , countFreeRefs
  , expSize
  , isNonRecursiveLiteral
  , noAnn
  , paramName
  , setAnn
  , subexpressions
  )

{- | The first argument is the @inline always@ name set of the module's
'Language.PureScript.Backend.IR.Optimizer.InlinePolicy': a foreign
accessor under an explicit @always@ directive keeps its read pasted per
site — the same deference
'Language.PureScript.Backend.IR.Optimizer.shareForeignAccessors' pays.
-}
eliminateCommonSubexpressions ∷ Set QName → UberModule → SupplyM UberModule
eliminateCommonSubexpressions alwaysInline uber = do
  bindings ← traverse (traverse (traverse cse)) (uberModuleBindings uber)
  exports ← traverse (traverse cse) (uberModuleExports uber)
  pure uber {uberModuleBindings = bindings, uberModuleExports = exports}
 where
  -- A top-level right-hand side compiles into the chunk's main
  -- function, which binds no parameters.
  cse = cseBlock alwaysInline 0

--------------------------------------------------------------------------------
-- The rewrite -----------------------------------------------------------------

{- | One alpha-equivalence class of candidate occurrences within a block:
how many, the first occurrence (the copy that survives as the shared
right-hand side), and its traversal-order position (the selection
tie-break, for deterministic output).
-}
data Group = Group
  { groupCount ∷ Natural
  , groupRep ∷ Exp
  , groupOrder ∷ Natural
  }

{- | Process one block (see the module header): hoist eligible groups one
round at a time, then descend into the nested blocks — the 'AbsN' bodies
— that remain, the hoisted right-hand sides included.
-}
cseBlock ∷ Set QName → Int → Exp → SupplyM Exp
cseBlock alwaysInline paramCount block = do
  let analysis = collectBlock block
      eligible =
        [ (key, grp)
        | -- Every hoist adds one local to the enclosing function, and
        -- each round's re-collection counts the previously minted
        -- bindings, so the budget is re-checked per hoist. See
        -- 'cseLocalsCeiling'.
        blockLocalCount analysis + paramCount < cseLocalsCeiling
        , (key, grp) ← Map.toList (blockGroups analysis)
        , groupCount grp >= 2
        , Set.disjoint (freeLocalNames (groupRep grp)) (blockBound analysis)
        , -- See 'eliminateCommonSubexpressions': an @inline always@
        -- accessor read stays pasted per site.
        maybe True (`Set.notMember` alwaysInline) $
          foreignAccessorQName (groupRep grp)
        ]
  case sortOn selectionOrder eligible of
    [] → descendInnerBlocks alwaysInline block
    (key, Group {groupRep}) : _ → do
      name ← freshName "$cse"
      let binding = Standalone (noAnn, name, setAnn noAnn groupRep)
      cseBlock alwaysInline paramCount $
        Let noAnn (binding :| []) (replaceOccurrences key name block)
 where
  selectionOrder ∷ (RawExp (), Group) → (Down Natural, Natural)
  selectionOrder (_key, grp) = (Down (expSize (groupRep grp)), groupOrder grp)

{- | The per-block locals budget, guarding Lua 5.1's
200-locals-per-function cap (@LUAI_MAXVARS@ — see
"Language.PureScript.Backend.Lua.Limits"). A block maps onto the body
of one generated Lua function (or is split across several by the
expression-position scope wrappers, which only widens the margin), and
each of its 'Let'-bound names — the discard binder of every magic-do
statement included — costs a local slot, so a magic-do chunk arrives
here with up to 150 of them already. Sharing is an optimization, never
a correctness need, so past this many locals (the enclosing lambda's
parameters included) a block simply gets no further hoists. The gap to
200 is headroom for what comes after this pass: the @$tmp@\/@$kont@
seals of flattenDeepBinds and the locals of hand-written fixture code.
-}
cseLocalsCeiling ∷ Int
cseLocalsCeiling = 160

-- | Recurse into the 'AbsN' bodies of a finished block.
descendInnerBlocks ∷ Set QName → Exp → SupplyM Exp
descendInnerBlocks alwaysInline = \case
  AbsN ann params body →
    AbsN ann params <$> cseBlock alwaysInline (length params) body
  other →
    traverseOf subexpressions (descendInnerBlocks alwaysInline) other

{- | Candidate groups of a block, keyed by canonical form, along with
every name the block binds (its 'Let' binders — 'AbsN' parameters bound
within the block can only be referenced from the inner blocks their
bodies are). The walk records every candidate and keeps descending
through the non-'AbsN' ones — their subexpressions evaluate when they
do, so a nested repeat still belongs to this block — while an 'AbsN' is
recorded as one occurrence and its body left to its own block. The block
root itself is never recorded: every other occurrence would be its own
proper subexpression, and no expression alpha-equals one.
-}
collectBlock ∷ Exp → BlockAnalysis
collectBlock root =
  execState
    (goRoot root)
    BlockAnalysis
      { blockGroups = Map.empty
      , blockBound = Set.empty
      , blockLocalCount = 0
      , blockNextOrder = 0
      }
 where
  goRoot ∷ Exp → State BlockAnalysis ()
  goRoot = \case
    AbsN {} → pass -- the root lambda's body is an inner block
    e → recordLetBinders e *> descend e

  go ∷ Exp → State BlockAnalysis ()
  go e
    | isCandidate e = do
        record e
        case e of
          AbsN {} → pass
          _ → descend e
    | otherwise = recordLetBinders e *> descend e

  -- The scope guard set — every name the block binds, the root node's
  -- own binders included (the hoist point is above the root) — plus
  -- the locals budget count, which counts binder occurrences rather
  -- than the name set: the discard binder repeats, one local slot per
  -- magic-do statement.
  recordLetBinders ∷ Exp → State BlockAnalysis ()
  recordLetBinders = \case
    Let _ groupings _ →
      modify (addBound (bindingNames =<< toList groupings))
    -- LetValues binders are block-bound names and local slots exactly
    -- like Let binders: a hoist whose representative references one
    -- would float above its binding and dangle.
    LetValues _ params _ _ →
      modify (addBound (mapMaybe paramName (toList params)))
    _ → pass
   where
    addBound ∷ [Name] → BlockAnalysis → BlockAnalysis
    addBound names s =
      s
        { blockBound = foldr Set.insert (blockBound s) names
        , blockLocalCount = blockLocalCount s + length names
        }

  descend ∷ Exp → State BlockAnalysis ()
  descend = traverse_ go . toListOf subexpressions

  record ∷ Exp → State BlockAnalysis ()
  record e = modify \s →
    s
      { blockGroups =
          Map.insertWith
            (\_new old → old {groupCount = groupCount old + 1})
            (alphaKey e)
            Group {groupCount = 1, groupRep = e, groupOrder = blockNextOrder s}
            (blockGroups s)
      , blockNextOrder = blockNextOrder s + 1
      }

data BlockAnalysis = BlockAnalysis
  { blockGroups ∷ Map (RawExp ()) Group
  , blockBound ∷ Set Name
  , blockLocalCount ∷ Int
  {- ^ 'Let'-binder occurrences in the block — the local slots its
  enclosing Lua function pays for. See 'cseLocalsCeiling'.
  -}
  , blockNextOrder ∷ Natural
  }

{- | Replace every occurrence of the group within the block by a
reference to the shared binding. Mirrors the collection walk: descends
through non-'AbsN' candidates, never into an 'AbsN' body, so exactly
the counted occurrences are replaced.
-}
replaceOccurrences ∷ RawExp () → Name → Exp → Exp
replaceOccurrences key name = goRoot
 where
  goRoot ∷ Exp → Exp
  goRoot = \case
    e@AbsN {} → e
    e → over subexpressions go e

  go ∷ Exp → Exp
  go e
    | isCandidate e, alphaKey e == key = Ref noAnn (Local name)
    | AbsN {} ← e = e
    | otherwise = over subexpressions go e

--------------------------------------------------------------------------------
-- Candidates ------------------------------------------------------------------

{- | An expression worth binding once and sharing: effect-free by
construction /and/ an allocation or a read — never a bare reference or
scalar, which are cheaper in place than through another local. See the
module header for the classes and their licence.
-}
isCandidate ∷ RawExp ann → Bool
isCandidate = \case
  AbsN {} → True
  LiteralArray _ elems@(_ : _) → all isEffectFreeValue elems
  LiteralObject _ props@(_ : _) → all (isEffectFreeValue . snd) props
  e
    | isRefProjection e → True
    | Just args ← saturatedCtorApp e → all isEffectFreeValue args
    | otherwise → False

{- | Evaluating the expression can at most allocate: no divergence, no
exception, no effect. The closure of the candidate classes over their
constituents ('Ctor' arguments, literal elements), plus the bare
references and scalars excluded from 'isCandidate' only as not worth
sharing.
-}
isEffectFreeValue ∷ RawExp ann → Bool
isEffectFreeValue e =
  case e of
    Ref {} → True
    LiteralArray _ elems → all isEffectFreeValue elems
    LiteralObject _ props → all (isEffectFreeValue . snd) props
    AbsN {} → True
    _
      | isNonRecursiveLiteral e → True
      | isRefProjection e → True
      | Just args ← saturatedCtorApp e → all isEffectFreeValue args
      | otherwise → False

{- | A single read — a projection, an index\/length read, a tag read —
over a base that is never nil at runtime: a reference (a well-typed
base value is a table), or a chain of /record/ reads over one (record
rows are static, so every link exists no matter which data variant is
scrutinized).

A read over a sum-variant slot ('DataArgumentByIndex', 'ArrayIndex')
does not qualify as a base: the pattern matcher emits chains like
@ReflectCtor (DataArgumentByIndex 0 e)@ only under the tag guard that
establishes the variant, and for the value actually present the slot
can be nil — evaluating the read /yields/ nil harmlessly, but a further
read through it throws, so hoisting the chain above its guard turns a
non-matching variant into a runtime error (pinned by the @classify@
oracle of the @Golden.CSE@ test).
-}
isRefProjection ∷ RawExp ann → Bool
isRefProjection = \case
  ObjectProp _ base _ → isNilSafeBase base
  ArrayIndex _ base _ → isNilSafeBase base
  PrimLen _ base → isNilSafeBase base
  ReflectCtor _ base → isNilSafeBase base
  DataArgumentByIndex _ _ _ base → isNilSafeBase base
  _ → False
 where
  isNilSafeBase ∷ RawExp ann → Bool
  isNilSafeBase = \case
    Ref {} → True
    ObjectProp _ base _ → isNilSafeBase base
    _ → False

{- | The field arguments of an in-place 'Ctor' node, which is saturated by
construction (see Note [Constructor applications are saturated]). A partial
application is a call of the curried wrapper — a 'Ref'-headed spine, a call
like any other — and is deliberately not recognised.
-}
saturatedCtorApp ∷ RawExp ann → Maybe [RawExp ann]
saturatedCtorApp = \case
  Ctor _ _ _ _ _ args → Just args
  _ → Nothing

--------------------------------------------------------------------------------
-- Alpha-equivalence keys ------------------------------------------------------

{- | The canonical form occurrences are grouped by: annotations dropped
and every binder bound within the expression renamed positionally, so
two expressions have equal keys iff they are alpha-equivalent up to
annotations (the 'Language.PureScript.Backend.IR.Types.alphaEq' relation
weakened by ignoring the annotations optimization sheds unevenly).

Binders are resolved to their references by name, so the key is correct
under the GUC discipline the pass runs under (the blind descent of
'Language.PureScript.Backend.IR.Types.freshenBinders'; the discard
binder @_@ is exempt from uniqueness and referenced by nothing, so it
stays unrenamed). Free references keep their names; a positional
@$key\<n\>@ name cannot collide with one, because @$@ never occurs in a
source identifier and every supply-minted name uses another prefix.
-}
alphaKey ∷ RawExp ann → RawExp ()
alphaKey = canonicalize . void
 where
  canonicalize ∷ RawExp () → RawExp ()
  canonicalize e = evalState (go Map.empty e) 0

  go ∷ Map Name Name → RawExp () → State Natural (RawExp ())
  go renames = \case
    r@(Ref ann qname)
      | Local name ← qname
      , Just canon ← Map.lookup name renames →
          pure (Ref ann (Local canon))
      | otherwise → pure r
    AbsN ann params body → do
      (renames', params') ← mapAccumM renameParam renames params
      AbsN ann params' <$> go renames' body
    Let ann binds body → do
      -- Under unique binders no Let name can be referenced before it is
      -- bound, so all the groupings can enter the rename map up front
      -- (as in 'freshenBinders').
      renames' ←
        foldlM
          ( \rs name → do
              name' ← mint
              pure (Map.insert name name' rs)
          )
          renames
          (filter (/= discardName) (bindingNames =<< toList binds))
      let renameBound (bindAnn, name, expr) =
            (bindAnn,Map.findWithDefault name name renames',)
              <$> go renames' expr
      Let ann <$> traverse (traverse renameBound) binds <*> go renames' body
    -- The RHS is canonicalized under the incoming map — the binders
    -- scope over the body only (Note [Multi-value results]).
    LetValues ann params rhs body → do
      rhs' ← go renames rhs
      (renames', params') ← mapAccumM renameParam renames params
      LetValues ann params' rhs' <$> go renames' body
    other → traverseOf subexpressions (go renames) other

  renameParam
    ∷ Map Name Name
    → Parameter ()
    → State Natural (Map Name Name, Parameter ())
  renameParam rs = \case
    p@(ParamUnused _paramAnn) → pure (rs, p)
    ParamNamed paramAnn name → do
      name' ← mint
      pure (Map.insert name name' rs, ParamNamed paramAnn name')

  mint ∷ State Natural Name
  mint = state \n → (Name ("$key" <> show n), n + 1)

--------------------------------------------------------------------------------
-- Helper functions ------------------------------------------------------------

-- | The locally-bound names an expression references freely.
freeLocalNames ∷ Exp → Set Name
freeLocalNames e =
  Set.fromList [name | Local name ← Map.keys (countFreeRefs e)]
