-- | Let-bound records and record updates that are only ever read
-- | field-wise still allocate their tables (issue #240): the goldens
-- | pin the current boxed shapes so the scalar-replacement rewrite
-- | shows as a reviewable diff. Covers a record read at two fields
-- | (`fieldwise`), the defaults pattern — a literal read at a field
-- | and updated (`defaults`), a record-update chain read field-wise
-- | (`chained`), and a record that flows somewhere whole and must
-- | keep its allocation (`wholeValue`), the soundness guard.
-- @inline wholeValue never
module Golden.ScalarReplacement.Test where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)

-- | Read at two fields only: the table exists just to be projected.
fieldwise :: Int -> Int
fieldwise n =
  let
    r = { width: n + 1, height: n * 2 }
  in
    r.width + r.height

-- | The defaults pattern: a literal read at a field and used as the
-- | base of an update whose result is again read field-wise. The
-- | field set is statically known, so both tables are reconstructible.
defaults :: Int -> Int
defaults n =
  let
    opts = { verbose: 1, level: n }
    chosen = opts { verbose = 2 }
  in
    opts.level + chosen.verbose + chosen.level

-- | A record-update chain read field-wise: every intermediate copy
-- | exists only to be projected or updated again.
chained :: Int -> Int -> Int
chained a b =
  let
    r0 = { x: a, y: 0, z: 0 }
    r1 = r0 { y = b }
    r2 = r1 { z = a + b }
  in
    r2.x + r2.y + r2.z

-- | The record flows into a branch result as a whole value, so its
-- | allocation must stay.
wholeValue :: Int -> Int
wholeValue n =
  let
    r = { a: n, b: n + 1 }
    s = if r.a > 0 then r else r { a = 0 - r.a }
  in
    s.a + s.b

main :: Effect Unit
main = do
  logShow (fieldwise 10)
  logShow (defaults 5)
  logShow (chained 3 4)
  logShow (wholeValue 5)
  logShow (wholeValue (-3))
