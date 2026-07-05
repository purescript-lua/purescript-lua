module Language.PureScript.PSString.Spec where

import Data.Char qualified as Char
import Data.Text qualified as Text
import Language.PureScript.PSString (PSString, decodeStringEscaping, mkString)
import Test.Hspec (Spec, describe, it, shouldBe)

spec ∷ Spec
spec = describe "decodeStringEscaping" do
  it "escapes a control character below U+0080 as a bare \\ddd decimal escape" do
    decodeStringEscaping (mkString (Text.singleton '\ESC')) `shouldBe` "\\27"

  it "does not pad a \\ddd escape when it is not followed by a digit" do
    decodeStringEscaping (mkString (Text.pack ['\ESC', '['])) `shouldBe` "\\27["

  it "zero-pads a \\ddd escape immediately followed by a literal digit" do
    decodeStringEscaping (mkString (Text.pack ['\ESC', '1'])) `shouldBe` "\\0271"

  it "escapes a code point above U+007F as one \\ddd per UTF-8 byte" do
    -- U+00A0 NO-BREAK SPACE, UTF-8 bytes 0xC2 0xA0.
    decodeStringEscaping (mkString (Text.singleton '\x00A0'))
      `shouldBe` "\\194\\160"

  it "escapes a lone surrogate as its WTF-8 bytes" do
    -- U+D800, a lead surrogate with no trailing surrogate to pair with.
    decodeStringEscaping loneLeadSurrogate `shouldBe` "\\237\\160\\128"

-- A PSString holding a single unpaired lead surrogate. Built from a raw
-- 'Char' rather than 'mkString' because GHC's 'Char' (unlike 'Text') permits
-- surrogate code points, and 'PSString's 'fromString' passes them through
-- unvalidated. See Note [PSString is UTF-16 code units, not text].
loneLeadSurrogate ∷ PSString
loneLeadSurrogate = fromString [Char.chr 0xD800]
