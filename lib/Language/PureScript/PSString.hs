module Language.PureScript.PSString
  ( PSString
  , toUTF16CodeUnits
  , decodeString
  , decodeStringEither
  , decodeStringWithReplacement
  , decodeStringEscaping
  , prettyPrintStringJS
  , mkString
  ) where

import Control.Exception (evaluate, try)
import Data.Aeson qualified as A
import Data.Aeson.Types qualified as A
import Data.Bits (shiftR)
import Data.ByteString qualified as BS
import Data.Char qualified as Char
import Data.IntCast (intCast)
import Data.Scientific (toBoundedInteger)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf16BE)
import Data.Vector qualified as V
import Numeric (showHex)
import System.IO.Unsafe (unsafePerformIO)
import Text.Show (Show (..))
import Prelude hiding (show)

{- Note [PSString is UTF-16 code units, not text]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A PSString is a sequence of UTF-16 code units that does not necessarily
represent well-formed UTF-16 text. It may contain lone surrogates: code
units in U+D800..U+DFFF that are not part of a surrogate pair. This is
faithful to PureScript, where a string literal can hold any code-unit
sequence.

Two consequences are load-bearing across the compiler.

Dual JSON encoding. Because JSON parsers disagree on lone surrogates inside
JSON strings, the 'A.ToJSON' instance emits a plain JSON string only when
that is lossless (no lone surrogates) and otherwise falls back to an array
of UTF-16 code units (integers). The 'A.FromJSON' instance therefore accepts
both shapes. CoreFn reading relies on this for record labels and string
literals (see 'Language.PureScript.CoreFn.FromJSON').

Decode-or-escape into Lua. A lone surrogate has no corresponding 'Char', so
code generation never decodes literal data with 'decodeString'. It uses
'decodeStringEscaping', which renders decodable code points directly and
emits a lone surrogate as a \xNNNNNN escape. The IR string and char literal
sites and the Lua backend rely on this to avoid failing on otherwise-legal
PureScript strings.
-}

{- | A sequence of UTF-16 code units, not necessarily well-formed UTF-16
text. See Note [PSString is UTF-16 code units, not text].
-}
newtype PSString = PSString {toUTF16CodeUnits ∷ [Word16]}
  deriving stock (Eq, Ord, Generic)
  deriving newtype (Semigroup, Monoid)

{- | Produces a string literal that would represent the same data if
inserted into a PureScript source file.
-}
instance Show PSString where
  show = show . codePoints

{- |
Decode a PSString to a String, representing any lone surrogates as the
reserved code point with that index. Warning: if there are any lone
surrogates, converting the result to Text via Data.Text.pack will result in
loss of information as those lone surrogates will be replaced with U+FFFD
REPLACEMENT CHARACTER. Because this function requires care to use correctly,
we do not export it.
-}
codePoints ∷ PSString → String
codePoints = map (either (Char.chr . intCast) id) . decodeStringEither

{- |
Decode a PSString as UTF-16 text. Lone surrogates will be replaced with
U+FFFD REPLACEMENT CHARACTER
-}
decodeStringWithReplacement ∷ PSString → String
decodeStringWithReplacement = map (fromRight '\xFFFD') . decodeStringEither

{- |
Decode a PSString as UTF-16. Lone surrogates in the input are represented in
the output with the Left constructor; characters which were successfully
decoded are represented with the Right constructor.
-}
decodeStringEither ∷ PSString → [Either Word16 Char]
decodeStringEither = unfoldr decode . toUTF16CodeUnits
 where
  decode ∷ [Word16] → Maybe (Either Word16 Char, [Word16])
  decode (h : l : rest)
    | isLead h && isTrail l =
        Just (Right (unsurrogate h l), rest)
  decode (c : rest) | isSurrogate c = Just (Left c, rest)
  decode (c : rest) = Just (Right (toChar c), rest)
  decode [] = Nothing

  unsurrogate ∷ Word16 → Word16 → Char
  unsurrogate h l =
    toEnum $
      (toInt h - 0xD800) * 0x400
        + (toInt l - 0xDC00)
        + 0x10000

{- |
Attempt to decode a PSString as UTF-16 text. This will fail (returning
Nothing) if the argument contains lone surrogates.
-}
decodeString ∷ PSString → Either UnicodeException Text
decodeString =
  decodeEither . BS.pack . concatMap unpair . toUTF16CodeUnits
 where
  unpair w = [highByte w, lowByte w]

  -- Deliberate narrowing: fromIntegral keeps the low 8 bits, which is exactly
  -- the low byte we want. intCast would (correctly) reject Word16 → Word8.
  lowByte ∷ Word16 → Word8
  lowByte = fromIntegral

  -- The shiftR 8 leaves a value in 0..255, so the narrowing to Word8 is always
  -- exact; intCast cannot see that bound statically, so keep fromIntegral.
  highByte ∷ Word16 → Word8
  highByte = fromIntegral . (`shiftR` 8)

  -- Based on a similar function from Data.Text.Encoding for utf8. This is a
  -- safe usage of unsafePerformIO because there are no side effects after
  -- handling any thrown UnicodeExceptions.
  decodeEither ∷ ByteString → Either UnicodeException Text
  decodeEither = unsafePerformIO . try . evaluate . decodeUtf16BE

instance IsString PSString where
  fromString a = PSString $ concatMap encodeUTF16 a
   where
    surrogates ∷ Char → (Word16, Word16)
    surrogates c = (toWord (h + 0xD800), toWord (l + 0xDC00))
     where
      (h, l) = divMod (fromEnum c - 0x10000) 0x400

    encodeUTF16 ∷ Char → [Word16]
    encodeUTF16 c | fromEnum c > 0xFFFF = [high, low]
     where
      (high, low) = surrogates c
    encodeUTF16 c = [toWord $ fromEnum c]

instance A.ToJSON PSString where
  toJSON str =
    case rightToMaybe (decodeString str) of
      Just t → A.toJSON t
      Nothing → A.toJSON (toUTF16CodeUnits str)

instance A.FromJSON PSString where
  parseJSON a = jsonString <|> arrayOfCodeUnits
   where
    jsonString = fromString <$> A.parseJSON a

    arrayOfCodeUnits = PSString <$> parseArrayOfCodeUnits a

    parseArrayOfCodeUnits ∷ A.Value → A.Parser [Word16]
    parseArrayOfCodeUnits =
      A.withArray
        "array of UTF-16 code units"
        (traverse parseCodeUnit . V.toList)

    parseCodeUnit ∷ A.Value → A.Parser Word16
    parseCodeUnit b =
      A.withScientific
        "two-byte non-negative integer"
        (maybe (A.typeMismatch "" b) return . toBoundedInteger)
        b

{- |
Decode a PSString as UTF-16, using PureScript escape sequences.
-}
decodeStringEscaping ∷ PSString → Text
decodeStringEscaping s = foldMap encodeChar (decodeStringEither s)
 where
  encodeChar ∷ Either Word16 Char → Text
  encodeChar (Left c) = "\\x" <> showHex' 6 c
  encodeChar (Right c)
    | c == '\t' = "\\t"
    | c == '\r' = "\\r"
    | c == '\n' = "\\n"
    | c == '"' = "\\\""
    | c == '\'' = "\\\'"
    | c == '\\' = "\\\\"
    | shouldPrint c = T.singleton c
    | otherwise = "\\x" <> showHex' 6 (Char.ord c)

  -- Note we do not use Data.Char.isPrint here because that includes things
  -- like zero-width spaces and combining punctuation marks, which could be
  -- confusing to print unescaped.
  shouldPrint ∷ Char → Bool
  -- The standard space character, U+20 SPACE, is the only space char we should
  -- print without escaping
  shouldPrint ' ' = True
  shouldPrint c =
    Char.generalCategory c
      `elem` [ Char.UppercaseLetter
             , Char.LowercaseLetter
             , Char.TitlecaseLetter
             , Char.OtherLetter
             , Char.DecimalNumber
             , Char.LetterNumber
             , Char.OtherNumber
             , Char.ConnectorPunctuation
             , Char.DashPunctuation
             , Char.OpenPunctuation
             , Char.ClosePunctuation
             , Char.InitialQuote
             , Char.FinalQuote
             , Char.OtherPunctuation
             , Char.MathSymbol
             , Char.CurrencySymbol
             , Char.ModifierSymbol
             , Char.OtherSymbol
             ]

{- |
Pretty print a PSString, using JavaScript escape sequences. Intended for
use in compiled JS output.
-}
prettyPrintStringJS ∷ PSString → Text
prettyPrintStringJS s = "\"" <> foldMap encodeChar (toUTF16CodeUnits s) <> "\""
 where
  encodeChar ∷ Word16 → Text
  encodeChar c | c > 0xFF = "\\u" <> showHex' 4 c
  encodeChar c | c > 0x7E || c < 0x20 = "\\x" <> showHex' 2 c
  encodeChar c | toChar c == '\b' = "\\b"
  encodeChar c | toChar c == '\t' = "\\t"
  encodeChar c | toChar c == '\n' = "\\n"
  encodeChar c | toChar c == '\v' = "\\v"
  encodeChar c | toChar c == '\f' = "\\f"
  encodeChar c | toChar c == '\r' = "\\r"
  encodeChar c | toChar c == '"' = "\\\""
  encodeChar c | toChar c == '\\' = "\\\\"
  encodeChar c = T.singleton $ toChar c

showHex' ∷ Enum a ⇒ Int → a → Text
showHex' width c =
  let hs = showHex (fromEnum c) ""
   in T.pack (replicate (width - length hs) '0' <> hs)

isLead ∷ Word16 → Bool
isLead h = h >= 0xD800 && h <= 0xDBFF

isTrail ∷ Word16 → Bool
isTrail l = l >= 0xDC00 && l <= 0xDFFF

isSurrogate ∷ Word16 → Bool
isSurrogate c = isLead c || isTrail c

toChar ∷ Word16 → Char
toChar = toEnum . intCast

-- Deliberate narrowing: callers (surrogate encoding in 'fromString') guarantee
-- the Int is already in Word16 range, so the truncation never loses data.
toWord ∷ Int → Word16
toWord = fromIntegral

toInt ∷ Word16 → Int
toInt = intCast

mkString ∷ Text → PSString
mkString = fromString . T.unpack
