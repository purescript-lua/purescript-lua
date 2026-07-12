module Golden.DirectivesFile.Test where

import Prelude

import Golden.DirectivesFile.M1 (incr, keep)

-- `incr` folds to constants here: the directives file (always) beats
-- the exported directive (never).
inlined :: Int
inlined = incr 1 + incr 2

-- `keep` stays a shared call: the local directive in M1 (never) beats
-- the directives file (always).
kept :: Int
kept = keep 1 + keep 2
