-- Exercises Data.String.CodePoints end to end on the released package set
-- (purescript-lua/purescript-lua-strings v6.2.0). The test string mixes UTF-8 widths
-- 1..4: 'a' (1 byte), 'é' (2), 'Я' (2, Cyrillic), '𝐀' (4, astral), 'z' (1).
-- Output is all Ints/Bools via fromEnum so the golden stays ASCII and does
-- not depend on how strings are shown.
module Golden.StringCodePoints.Test where

import Prelude

import Data.Enum (fromEnum, toEnum)
import Data.Maybe (fromJust)
import Data.String.CodePoints (CodePoint)
import Data.String.CodePoints as SCP
import Data.String.CodeUnits as SCU
import Effect (Effect)
import Effect.Console (logShow)
import Partial.Unsafe (unsafePartial)

str :: String
str = "aéЯ𝐀z"

codes :: String -> Array Int
codes = map fromEnum <<< SCP.toCodePointArray

main :: Effect Unit
main = do
  -- decode every code point
  logShow (codes str)
  -- code-point length vs byte length
  logShow (SCP.length str)
  logShow (SCU.length str)
  -- take/drop split on a code-point boundary (not mid-multibyte)
  logShow (codes (SCP.take 2 str))
  logShow (codes (SCP.drop 2 str))
  -- indexing, including the astral code point and out of range
  logShow (fromEnum <$> SCP.codePointAt 0 str)
  logShow (fromEnum <$> SCP.codePointAt 3 str)
  logShow (fromEnum <$> SCP.codePointAt 5 str)
  -- uncons head and the decoded tail
  logShow ((fromEnum <<< _.head) <$> SCP.uncons str)
  logShow ((codes <<< _.tail) <$> SCP.uncons str)
  -- encode round-trips back to the original bytes
  logShow (SCP.fromCodePointArray (SCP.toCodePointArray str) == str)
  -- singleton of an astral code point decodes back to itself
  logShow (codes (SCP.singleton (cp 0x1D400)))

cp :: Int -> CodePoint
cp = unsafePartial fromJust <<< toEnum
