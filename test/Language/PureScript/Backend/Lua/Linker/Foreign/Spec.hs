{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Linker.Foreign.Spec where

import Data.List (isInfixOf)
import Data.String.Interpolate (__i)
import Language.PureScript.Backend.Lua.Key (Key (..))
import Language.PureScript.Backend.Lua.Linker.Foreign
import Language.PureScript.Backend.Lua.Name (unsafeName)
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Parser (renderParseError)
import Language.PureScript.Backend.Lua.Types (ParamF (..))
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Path (relfile, toFilePath, (</>))
import Path.IO (withSystemTempDir)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldSatisfy)
import Test.Hspec.Expectations.Pretty (shouldBe)

spec ∷ Spec
spec = describe "Foreign module parser" do
  it "parses a foreign module into header statements and AST exports" do
    parseForeign (rawHeader <> "\n" <> rawExports) >>= \case
      Left err → expectationFailure (show err)
      Right Source {header, returnComments, exports} → do
        header `shouldBe` expectedHeader
        returnComments `shouldBe` []
        toList exports `shouldBe` expectedExports

  it "keeps module-level comments of a header-less file on the return" do
    parseForeign commentOnlyModule >>= \case
      Left err → expectationFailure (show err)
      Right Source {header, returnComments, exports} → do
        header `shouldBe` []
        returnComments `shouldBe` ["-- Module-level commentary."]
        toList exports
          `shouldBe` [(unsafeKey "topInt", ([], Lua.Integer 2147483647))]

  it "reports a syntax error inside an export value at compile time" do
    -- The lexical splitter accepted anything with balanced parens; the
    -- parser rejects this file outright (issue #173).
    result ← parseForeign "return { foo = (42 + ) }"
    result `shouldSatisfy` \case
      Left (ForeignErrorParse _path _err) → True
      _ → False

  it "rejects an ambiguous line-broken call the way `luac` does" do
    -- `local x = f` followed by a line starting with `(` is Lua 5.1's
    -- "ambiguous syntax (function call x new statement)".
    result ← parseForeign "local x = f\n(g).y = 1\nreturn { x = x }"
    case result of
      Left (ForeignErrorParse _path err) →
        renderParseError err
          `shouldSatisfy` isInfixOf "ambiguous syntax"
      other →
        expectationFailure
          ("Expected an ambiguity parse error, got: " <> show other)

  it "rejects a file that does not end in `return { ... }`" do
    result ← parseForeign "local x = 1"
    result `shouldSatisfy` \case
      Left (ForeignNoExportsReturn _path) → True
      _ → False

  it "rejects an empty exports table" do
    result ← parseForeign "return {}"
    result `shouldSatisfy` \case
      Left (ForeignNoExports _path) → True
      _ → False

  it "rejects an export keyed by a non-identifier" do
    result ← parseForeign "return { [1] = 42 }"
    result `shouldSatisfy` \case
      Left (ForeignUnsupportedExportKey _path) → True
      _ → False

parseForeign ∷ String → IO (Either Error Source)
parseForeign contents =
  withSystemTempDir "foreigns" \foreigns → do
    let path = toFilePath $ foreigns </> [relfile|Foo.lua|]
    writeFile path contents
    parseForeignSource foreigns path

rawHeader ∷ String
rawHeader =
  [__i|
    -- header
    local function foo()
      return 42
    end
    local boo = "boo"
    local zoo = boo .. "zoo"
  |]

-- Values are no longer required to be wrapped in parens (compare `foo` and
-- `bar`); a reserved word appears as a bracketed string key.
rawExports ∷ String
rawExports =
  [__i|
    return {
      foo = 42,
      bar = ("ok"),
      -- baz doc
      baz = function(unused)
        return zoo
      end,
      [ "if"]= function() return "if" end,
    }
  |]

commentOnlyModule ∷ String
commentOnlyModule =
  [__i|
    -- Module-level commentary.
    return { topInt = 2147483647 }
  |]

expectedHeader ∷ [Lua.Annotated Lua.Comments Lua.StatementF]
expectedHeader =
  [
    ( ["-- header"]
    , Lua.LocalFunction
        [Lua.name|foo|]
        []
        [Lua.ann (Lua.return (Lua.Integer 42))]
    )
  , ([], Lua.local1 [Lua.name|boo|] (Lua.String "boo"))
  ,
    ( []
    , Lua.local1
        [Lua.name|zoo|]
        (Lua.varName [Lua.name|boo|] `Lua.concat` Lua.String "zoo")
    )
  ]

expectedExports ∷ [(Key, Lua.Annotated Lua.Comments Lua.ExpF)]
expectedExports =
  [ (unsafeKey "foo", ([], Lua.Integer 42))
  , -- parens around a single-valued expression are grouping and are dropped
    (unsafeKey "bar", ([], Lua.String "ok"))
  ,
    ( unsafeKey "baz"
    ,
      ( ["-- baz doc"]
      , Lua.functionDef
          [ParamNamed [Lua.name|unused|]]
          [Lua.return (Lua.varName [Lua.name|zoo|])]
      )
    )
  ,
    ( KeyReserved "if"
    , ([], Lua.functionDef [] [Lua.return (Lua.String "if")])
    )
  ]

unsafeKey ∷ Text → Key
unsafeKey = KeyName . unsafeName
