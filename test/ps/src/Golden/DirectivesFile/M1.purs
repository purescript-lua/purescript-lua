-- @inline export incr never
-- @inline keep never
module Golden.DirectivesFile.M1 where

import Prelude

-- The exported directive says never, but the directives file next to
-- Golden.DirectivesFile.Test overrides it with always: in that build
-- `incr` is inlined away. Compiled on its own (no file), the exported
-- never applies and the binding survives.
incr :: Int -> Int
incr x = x + 1

-- The local directive says never; the directives file says always and
-- loses: `keep` survives in every build.
keep :: Int -> Int
keep x = x + 2
