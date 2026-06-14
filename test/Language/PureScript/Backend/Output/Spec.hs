module Language.PureScript.Backend.Output.Spec (spec) where

import Language.PureScript.Backend.Output (withOutputFile)
import Path (parseRelFile, (</>))
import Path.IO (doesFileExist, withSystemTempDir)
import Test.Hspec (Spec, describe, it, shouldReturn)

spec ∷ Spec
spec = describe "Language.PureScript.Backend.Output" do
  it "withOutputFile creates the missing parent directory" do
    withSystemTempDir "pslua-output" \tmp → do
      file ← (tmp </>) <$> parseRelFile "nested/dir/out.lua"
      withOutputFile file (const pass)
      doesFileExist file `shouldReturn` True
