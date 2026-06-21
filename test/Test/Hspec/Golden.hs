{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies #-}

module Test.Hspec.Golden
  ( Golden (..)
  , defaultGolden
  , acceptableGolden
  )
where

import Data.Text qualified as Text
import Path (Abs, File, Path, parent, toFilePath)
import Path.IO (createDirIfMissing, doesFileExist)
import Test.Hspec.Core.Spec
  ( Example (..)
  , FailureReason (..)
  , Result (..)
  , ResultStatus (..)
  )

{- | Env var that opts back into the full expected/actual diff. By default a
golden mismatch reports only a bounded, line-oriented summary (the first
differing line plus a small window) so a run with many mismatches does not
hold two full pretty-printed blobs — and their diff — per failure. Set this
(to anything) for the complete diff, à la tasty-golden's options.
-}
fullDiffEnvVar ∷ String
fullDiffEnvVar = "PSLUA_GOLDEN_FULL_DIFF"

{- | Env var that, when set, makes a mismatching golden be /accepted/: the
golden file is rewritten in place with the actual output and the test passes,
à la tasty-golden's @--accept@. This avoids deleting goldens by hand (or with
@scripts/golden_reset@) when a codegen/optimizer change legitimately moves the
output.

Acceptance only applies to goldens marked 'acceptable' (the structural
@golden.ir@ / @golden.lua@). The @eval/golden.txt@ oracle is built with
'defaultGolden' (@acceptable = False@) and is therefore never auto-accepted —
its hand-verified program output must change only by deliberate review.
-}
acceptEnvVar ∷ String
acceptEnvVar = "PSLUA_GOLDEN_ACCEPT"

{- | Golden tests parameters

 @
 import           Data.Text (Text)
 import qualified Data.Text.IO as T

 goldenText :: Path Abs File -> Text -> Golden Text
 goldenText name actualOutput =
   Golden {
     output = actualOutput,
     encodePretty = prettyText,
     writeToFile = T.writeFile,
     readFromFile = T.readFile,
     goldenFile = ".specific-golden-dir" </> name </> "golden",
     actualFile = Just (".specific-golden-dir" </> name </> "actual"),
     failFirstTime = False
   }

 describe "myTextFunc" $
   it "generates the right output with the right params" $
     goldenText "myTextFunc" (myTextFunc params)
 @
-}
data Golden str = Golden
  { produceOutput ∷ IO str
  -- ^ Output
  , encodePretty ∷ str → String
  -- ^ Makes the comparison pretty when the test fails
  , writeToFile ∷ Path Abs File → str → IO ()
  -- ^ How to write into the golden file the file
  , readFromFile ∷ Path Abs File → IO str
  -- ^ How to read the file,
  , goldenFile ∷ Path Abs File
  -- ^ Where to read/write the golden file for this test.
  , actualFile ∷ Maybe (Path Abs File)
  {- ^ Where to save the actual file for this test.
  If it is @Nothing@ then no file is written.
  -}
  , failFirstTime ∷ Bool
  -- ^ Whether to record a failure the first time this test is run
  , acceptable ∷ Bool
  {- ^ Whether a mismatch may be accepted (golden rewritten in place) when
  'acceptEnvVar' is set. Keep 'False' for hand-verified oracles.
  -}
  }

instance Eq str ⇒ Example (Golden str) where
  type Arg (Golden str) = ()
  evaluateExample e = evaluateExample (\() → e)

instance Eq str ⇒ Example (arg → Golden str) where
  type Arg (arg → Golden str) = arg
  evaluateExample golden _ action _ = do
    ref ← newIORef (Result "" Success)
    action $ \arg → do
      r ← runGolden (golden arg)
      writeIORef ref (fromGoldenResult r)
    readIORef ref

-- | Transform a GoldenResult into a Result from Hspec
fromGoldenResult ∷ GoldenResult → Result
fromGoldenResult = \case
  SameOutput →
    Result "Golden and Actual output hasn't changed" Success
  Accepted →
    Result "Golden file accepted (PSLUA_GOLDEN_ACCEPT)" Success
  FirstExecutionSucceed →
    Result "First time execution. Golden file created." Success
  FirstExecutionFail →
    Result
      "First time execution. Golden file created."
      (Failure Nothing (Reason "failFirstTime is set to True"))
  MissmatchOutput expected actual →
    Result
      "Files golden and actual not match"
      (Failure Nothing (ExpectedButGot Nothing expected actual))
  MissmatchSummary summary →
    Result
      "Files golden and actual not match"
      (Failure Nothing (Reason summary))

defaultGolden
  ∷ Path Abs File
  → Maybe (Path Abs File)
  → IO Text
  → Golden Text
defaultGolden goldenFile actualFile produceOutput =
  Golden
    { produceOutput
    , encodePretty = toString
    , writeToFile = \f → writeFileBS (toFilePath f) . encodeUtf8
    , readFromFile = fmap decodeUtf8 . readFileBS . toFilePath
    , goldenFile
    , actualFile
    , failFirstTime = False
    , acceptable = False
    }

{- | Like 'defaultGolden', but the golden may be accepted in place when
'acceptEnvVar' is set (see there). Use for derived/structural goldens whose
content is a pure function of the code under test (e.g. generated IR or Lua),
NOT for hand-verified oracles.
-}
acceptableGolden
  ∷ Path Abs File
  → Maybe (Path Abs File)
  → IO Text
  → Golden Text
acceptableGolden goldenFile actualFile produceOutput =
  (defaultGolden goldenFile actualFile produceOutput) {acceptable = True}

-- | Possible results from a golden test execution
data GoldenResult
  = MissmatchOutput String String
  | -- | A bounded, line-oriented mismatch summary (the default).
    MissmatchSummary String
  | SameOutput
  | -- | A mismatch that was accepted: the golden file was rewritten in place.
    Accepted
  | FirstExecutionSucceed
  | FirstExecutionFail

{- | A bounded, line-oriented summary of a golden mismatch: the first differing
line, a small window of each side, the line counts, and a pointer to the actual
file. Keeps each failure O(window) instead of retaining two full blobs (and
their diff). Set 'fullDiffEnvVar' for the complete expected/actual diff.
-}
boundedSummary ∷ Maybe (Path Abs File) → String → String → String
boundedSummary mActual expected actual =
  let els = Text.lines (toText expected)
      als = Text.lines (toText actual)
      common = length (takeWhile (uncurry (==)) (zip els als))
      win = 8
      numbered ls =
        [ "    " <> show (common + i + 1) <> " | " <> toString l
        | (i, l) ← zip [0 ..] (take win (drop common ls))
        ]
   in toString . Text.unlines . fmap toText . concat $
        [
          [ "Golden mismatch (first difference at line "
              <> show (common + 1)
              <> ")."
          , "  expected: "
              <> show (length els)
              <> " line(s); actual: "
              <> show (length als)
              <> " line(s)."
          , "  expected, from the first difference:"
          ]
        , numbered els
        , ["  actual, from the first difference:"]
        , numbered als
        ,
          [ "  full actual output: " <> maybe "(not written)" toFilePath mActual
          , "  re-run with " <> fullDiffEnvVar <> "=1 for the complete diff."
          ]
        ]

-- | Runs a Golden test.
runGolden ∷ Eq str ⇒ Golden str → IO GoldenResult
runGolden Golden {..} = do
  let goldenTestDir = parent goldenFile
  createDirIfMissing True goldenTestDir
  goldenFileExist ← doesFileExist goldenFile
  output ← produceOutput

  case actualFile of
    Nothing → pass
    Just actual → do
      let actualDir = parent actual
      createDirIfMissing True actualDir
      writeToFile actual output

  if not goldenFileExist
    then do
      writeToFile goldenFile output
      pure $
        if failFirstTime
          then FirstExecutionFail
          else FirstExecutionSucceed
    else do
      contentGolden ← readFromFile goldenFile
      if contentGolden == output
        then pure SameOutput
        else do
          accept ← isJust <$> lookupEnv acceptEnvVar
          if accept && acceptable
            then do
              writeToFile goldenFile output
              pure Accepted
            else do
              wantFull ← isJust <$> lookupEnv fullDiffEnvVar
              pure
                if wantFull
                  then
                    MissmatchOutput
                      (encodePretty contentGolden)
                      (encodePretty output)
                  else
                    MissmatchSummary $
                      boundedSummary
                        actualFile
                        (encodePretty contentGolden)
                        (encodePretty output)
