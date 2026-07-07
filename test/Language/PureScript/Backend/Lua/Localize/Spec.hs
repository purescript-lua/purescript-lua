{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Localize.Spec where

import Data.String.Interpolate (__i)
import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Localize
  ( localizeChunk
  , maxCachedFieldsPerFunction
  )
import Language.PureScript.Backend.Lua.Name (name)
import Language.PureScript.Backend.Lua.Parser (unsafeParseStatements)
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import Test.Hspec (Expectation, Spec, describe, it)
import Test.Hspec.Expectations.Pretty (shouldBe)

spec ∷ Spec
spec = describe "Lua module-table field localization (#174)" do
  it "caches a field read twice within a function body" do
    [__i|
      local M = {}
      M.f = function(x) return M.a(x) + M.a(x) end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(x)
          local a = M.a
          return a(x) + a(x)
        end
        return { f = M.f }
      |]

  it "leaves a single straight-line read alone" do
    unchanged
      [__i|
        local M = {}
        M.f = function(x) return M.a(x) end
        return { f = M.f }
      |]

  it "caches a single read re-evaluated by a while loop" do
    [__i|
      local M = {}
      M.f = function(n)
        while true do
          if M.eq(n)(0) then return n end
          n = n - 1
        end
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(n)
          local eq = M.eq
          while true do
            if eq(n)(0) then return n end
            n = n - 1
          end
        end
        return { f = M.f }
      |]

  it "counts a while condition as re-evaluated per iteration" do
    [__i|
      local M = {}
      M.f = function(n)
        while M.check(n) do
          n = n - 1
        end
        return n
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(n)
          local check = M.check
          while check(n) do
            n = n - 1
          end
          return n
        end
        return { f = M.f }
      |]

  it "does not cache a conditional pair of reads (the naive-fib shape)" do
    -- Entry-hoisting would tax the base-case path with two table reads
    -- it never performs; measured as a ~25% PUC regression on fib.
    unchanged
      [__i|
        local M = {}
        M.fib = function(n)
          if n < 2 then
            return n
          else
            return M.fib(n - 1) + M.fib(n - 2)
          end
        end
        return { fib = M.fib }
      |]

  it "treats the right operand of and/or as conditional" do
    unchanged
      [__i|
        local M = {}
        M.f = function(x)
          return x and M.a(x) or M.a(0)
        end
        return { f = M.f }
      |]

  it "rewrites conditional occurrences of a field that qualifies" do
    [__i|
      local M = {}
      M.f = function(x)
        local y = M.a(x)
        local z = M.a(y)
        if x then return M.a(0) else return z end
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(x)
          local a = M.a
          local y = a(x)
          local z = a(y)
          if x then return a(0) else return z end
        end
        return { f = M.f }
      |]

  it "does not cache a read evaluated once before a loop" do
    unchanged
      [__i|
        local M = {}
        M.f = function(n)
          for i = M.start, 10 do
            n = n + i
          end
          return n
        end
        return { f = M.f }
      |]

  it "hoists reads inside an immediately-invoked scope to function entry" do
    [__i|
      local M = {}
      M.f = function(n)
        while true do
          if (function()
            if M.gt(n)(100) then return true else return false end
          end)() then
            return n
          end
          n = M.gt(n)(0) and n or 0
        end
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(n)
          local gt = M.gt
          while true do
            if (function()
              if gt(n)(100) then return true else return false end
            end)() then
              return n
            end
            n = gt(n)(0) and n or 0
          end
        end
        return { f = M.f }
      |]

  it "caches within a chunk-level immediately-invoked scope" do
    [__i|
      local M = {}
      M.a = 1
      return (function()
        local x = M.log(M.a)
        return M.log(x)
      end)()
    |]
      `localizesTo` [__i|
        local M = {}
        M.a = 1
        return (function()
          local log = M.log
          local x = log(M.a)
          return log(x)
        end)()
      |]

  it "leaves a nested closure to its own caching" do
    -- The outer function sees each field once (the closure boundary is
    -- not crossed); the closure itself sees M.a twice and caches it.
    [__i|
      local M = {}
      M.f = function(x)
        return function(y)
          return M.a(x) + M.a(y)
        end
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(x)
          return function(y)
            local a = M.a
            return a(x) + a(y)
          end
        end
        return { f = M.f }
      |]

  it "processes a local function body" do
    [__i|
      local M = {}
      M.f = function(x)
        local function go(n)
          return M.a(n) + M.a(n)
        end
        return go(x)
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(x)
          local function go(n)
            local a = M.a
            return a(n) + a(n)
          end
          return go(x)
        end
        return { f = M.f }
      |]

  it "picks a fresh cache name over an existing one" do
    [__i|
      local M = {}
      M.f = function(a)
        return M.a(a) + M.a(a)
      end
      return { f = M.f }
    |]
      `localizesTo` [__i|
        local M = {}
        M.f = function(a)
          local a_c1 = M.a
          return a_c1(a) + a_c1(a)
        end
        return { f = M.f }
      |]

  it "does not cache reads at chunk level" do
    unchanged
      [__i|
        local M = {}
        M.a = 1
        M.f = M.a + M.a
        return { f = M.f }
      |]

  it "caps the number of cached fields per function" do
    let fields =
          [1 .. maxCachedFieldsPerFunction + 1] <&> \(i ∷ Int) →
            "M.a" <> show i <> "(x) + M.a" <> show i <> "(x)"
        source ∷ Text =
          Text.unlines
            [ "local M = {}"
            , "M.f = function(x)"
            , "return " <> Text.intercalate " + " fields
            , "end"
            , "return { f = M.f }"
            ]
    case localizeChunk [name|M|] (unsafeParseStatements source) of
      [ _localM
        , Lua.Assign _vars (Lua.Ann (Lua.Function _params body) :| [])
        , _return
        ] →
          case body of
            Lua.Ann (Lua.Local names _inits) : _rest →
              length names `shouldBe` maxCachedFieldsPerFunction
            _ → fail "expected a cache Local at function entry"
      _ → fail "unexpected chunk shape"

  describe "stability precondition" do
    it "declines the whole chunk on a field write inside a function" do
      unchanged
        [__i|
          local M = {}
          M.f = function(x)
            M.a = x
            return M.a(x) + M.a(x)
          end
          return { f = M.f }
        |]

    it "declines the whole chunk on a bare module-table reference" do
      unchanged
        [__i|
          local M = {}
          M.f = function(x)
            return require("inspect")(M) and M.a(x) + M.a(x)
          end
          return { f = M.f }
        |]

    it "declines the whole chunk on a shadowing declaration" do
      unchanged
        [__i|
          local M = {}
          M.f = function(x)
            local M = { a = print }
            return M.a(x) + M.a(x)
          end
          return { f = M.f }
        |]

--------------------------------------------------------------------------------
-- Helper Functions ------------------------------------------------------------

render ∷ Lua.Chunk → Text
render =
  renderStrict . layoutPretty defaultLayoutOptions . Printer.printLuaChunk

localizesTo ∷ HasCallStack ⇒ Text → Text → Expectation
localizesTo source expected =
  render (localizeChunk [name|M|] (unsafeParseStatements source))
    `shouldBe` render (unsafeParseStatements expected)

unchanged ∷ HasCallStack ⇒ Text → Expectation
unchanged source = source `localizesTo` source
