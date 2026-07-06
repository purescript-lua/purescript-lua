module Golden.ForeignSharing.Test (main) where

import Prelude (Unit)

import Effect (Effect)
import Effect.Console (log)
import Golden.ForeignSharing.Token (Token, token)

foreign import same :: Token -> Token -> Boolean

sharedToken :: Int -> Token
sharedToken _ = token

main :: Effect Unit
main = log (if same (sharedToken 0) (sharedToken 1) then "shared" else "fresh")
