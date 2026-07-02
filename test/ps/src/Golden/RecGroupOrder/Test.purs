module Golden.RecGroupOrder.Test where

import Prelude

import Effect (Effect)
import Effect.Console (log)

store :: (Unit -> String) -> { run :: Unit -> String, tag :: String }
store f = { run: f, tag: "ok!" }

main :: Effect Unit
main = do
  let
    record = store (\_ -> record.tag)
  log (record.run unit)
