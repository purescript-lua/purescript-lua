{- | The renumbering core shared by the IR and Lua renumberers.

A compiler-minted name carries an index drawn from a monotone supply,
either suffix-minted as @base\<delim\>N@ or prefix-minted as
@\<delim\>tagN@. That index is pipeline history, not artifact structure:
any upstream change shifting how much supply earlier code consumes
renames every later binder, churning artifacts that are semantically
identical. A renumberer erases the history by reassigning the indices in
first-occurrence order, making a name a function of the artifact's own
structure.

Held here are the two delimiter-generic halves of that job: deciding
which digit runs of a name are supply-drawn and allocating their
replacements ('renumberedText'). The scope discipline — which references
a renamed binder must carry along — differs per artifact and stays with
each renumberer: 'Language.PureScript.Backend.IR.Renumber' (delimiter
@$@, which no source identifier can contain) and
'Language.PureScript.Backend.Lua.Renumber' (delimiter @_S_@, the
mangling 'Language.PureScript.Backend.Lua.Name.makeSafe' gives @$@ on
the way into the Lua AST).
-}
module Language.PureScript.Backend.Renumber
  ( Allocation
  , Delimiter (..)
  , noAllocation
  , renumberedText
  ) where

import Data.Char qualified as Char
import Data.Map qualified as Map
import Data.Text qualified as Text

{- Note [Supply-drawn digit runs]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A maximal digit run inside a name is /supply-drawn/ — an index that leaks
pipeline history — in exactly two shapes, mirroring the two minting
grammars (spelled below with the IR's @$@ delimiter):

  * it forms a whole delimited segment: @x$223@, and the same run
    embedded deeper in a derived name, @b$5$loop@ (the dispatcher a
    recursive group's leader @b$5@ lends its name to);

  * it terminates the tag of a prefix-minted name — one starting with the
    delimiter — as in @$cse1413@ or @$a1@.

Digit runs anywhere else are spelling, not supply: @add3@ keeps its @3@,
uncurrying's positional @f$p1@ keeps its @1@, and call-pattern
specialization's @pong$sc1Tuple@ keeps its @1@.

Renumbering assigns each distinct (piece-prefix, run) pair a fresh index
per prefix, counted up from 0 in first-occurrence order. Keying by the
run's original spelling keeps a derived name in step with the binder it
embeds: @b$5@ and @b$5$loop@ renumber to @b$0@ and @b$0$loop@. The
mapping is injective (same prefix → distinct indices; different prefixes
→ images differ outside their digit runs), and an image can never collide
with a name the renumbering leaves alone, because every image contains a
supply-drawn run and untouched names by definition contain none.
-}

--------------------------------------------------------------------------------
-- Allocation ------------------------------------------------------------------

{- | The separator between the segments of a minted name: @$@ in the IR,
its @_S_@ mangling in the Lua AST.
-}
newtype Delimiter = Delimiter Text

-- | The indices allocated so far, threaded through a renumbering.
data Allocation = Allocation
  { assigned ∷ Map (Text, Text) Natural
  -- ^ (piece-prefix, original digit run) → allocated index.
  , counters ∷ Map Text Natural
  -- ^ Next index to allocate, per piece-prefix.
  }

{- | The empty allocation. A renumberer restarts from it for each
namespace it renumbers independently of the others.
-}
noAllocation ∷ Allocation
noAllocation = Allocation mempty mempty

--------------------------------------------------------------------------------
-- Renumbering -----------------------------------------------------------------

{- | The name with every supply-drawn digit run replaced by a freshly
allocated index, or 'Nothing' when the name carries no such run (see
Note [Supply-drawn digit runs]) — which tells a caller the name is not
compiler-minted, rather than that it renumbered to itself. The predicate
reports spellings the allocation must not produce, for a caller whose
namespace also holds names it cannot rename.
-}
renumberedText
  ∷ Delimiter
  → (Text → Bool)
  → Text
  → Maybe (State Allocation Text)
renumberedText (Delimiter delim) reserved whole
  | any supplyDrawn piecesInContext =
      Just $
        Text.concat <$> forM piecesInContext \piece@(run, prefix, _next) →
          if supplyDrawn piece then allocate prefix run else pure run
  | otherwise = Nothing
 where
  -- Maximal runs of digits alternating with runs of non-digits.
  pieces = Text.groupBy (\a b → Char.isDigit a == Char.isDigit b) whole
  piecesInContext =
    [ (p, Text.concat (take i pieces), pieces !!? (i + 1))
    | (i, p) ← zip [0 ..] pieces
    ]

  supplyDrawn (p, prefix, next)
    | not (Text.all Char.isDigit p) = False
    | otherwise =
        atSegmentEnd
          && ( delim `Text.isSuffixOf` prefix -- whole segment: base$N
                 || ( delim `Text.isPrefixOf` whole -- prefix-minted: $tagN
                        && not
                          ( delim
                              `Text.isInfixOf` Text.drop (Text.length delim) prefix
                          )
                    )
             )
   where
    atSegmentEnd = maybe True (delim `Text.isPrefixOf`) next

  allocate ∷ Text → Text → State Allocation Text
  allocate prefix run = do
    Allocation {assigned, counters} ← get
    show <$> case Map.lookup (prefix, run) assigned of
      Just i → pure i
      Nothing → do
        let nextClear c
              | reserved (prefix <> show c) = nextClear (c + 1)
              | otherwise = c
            i = nextClear (Map.findWithDefault 0 prefix counters)
        put
          Allocation
            { assigned = Map.insert (prefix, run) i assigned
            , counters = Map.insert prefix (i + 1) counters
            }
        pure i
