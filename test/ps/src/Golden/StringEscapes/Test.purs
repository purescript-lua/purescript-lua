module Golden.StringEscapes.Test where

import Prelude
import Effect (Effect)
import Effect.Console (log)

-- The ESC control character (U+001B) must survive into the generated
-- Lua string literal byte-for-byte: ANSI color sequences are the most
-- common way for a control character to appear in a source literal.
main :: Effect Unit
main = log "\x1b[31mred\x1b[0m"
