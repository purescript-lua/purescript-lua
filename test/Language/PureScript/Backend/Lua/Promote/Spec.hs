{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

module Language.PureScript.Backend.Lua.Promote.Spec where

import Data.String.Interpolate (__i)
import Data.Tagged (Tagged (..))
import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Golden.Spec (compileCorefn, compileIr)
import Language.PureScript.Backend.Lua.Limits (LuaLimits (..), lua51Limits)
import Language.PureScript.Backend.Lua.Name (name)
import Language.PureScript.Backend.Lua.Parser (unsafeParseStatements)
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Promote (promoteChunk)
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Language.PureScript.Backend.Types (AppOrModule (..))
import Language.PureScript.Names qualified as PS
import Path (SomeBase (..), mkRelDir, toFilePath)
import Path.IO (withSystemTempFile)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import System.IO (hClose)
import System.Process.Typed (ExitCode (..), readProcessInterleaved)
import Test.Hspec (Expectation, Spec, describe, it, shouldSatisfy)
import Test.Hspec.Expectations.Pretty (shouldBe)

spec ∷ Spec
spec = describe "Lua two-tier top-level binding storage (#174)" do
  it "promotes bindings to chunk locals and drops the module table" do
    [__i|
      local M = {}
      M.a = 1
      M.f = function(x) return M.a + x end
      return { f = M.f, a = M.a }
    |]
      `promotesTo` [__i|
        local a = 1
        local f = function(x) return a + x end
        return { f = f, a = a }
      |]

  it "pre-declares a self-recursive binding" do
    [__i|
      local M = {}
      M.fib = function(n)
        if n < 2 then return n else return M.fib(n - 1) + M.fib(n - 2) end
      end
      return { fib = M.fib }
    |]
      `promotesTo` [__i|
        local fib
        fib = function(n)
          if n < 2 then return n else return fib(n - 1) + fib(n - 2) end
        end
        return { fib = fib }
      |]

  it "pre-declares only the forward-referenced group members" do
    [__i|
      local M = {}
      M.even = function(n)
        if n == 0 then return true else return M.odd(n - 1) end
      end
      M.odd = function(n)
        if n == 0 then return false else return M.even(n - 1) end
      end
      return { even = M.even }
    |]
      `promotesTo` [__i|
        local odd
        local even = function(n)
          if n == 0 then return true else return odd(n - 1) end
        end
        odd = function(n)
          if n == 0 then return false else return even(n - 1) end
        end
        return { even = even }
      |]

  it "keeps overflow bindings in the module table on a short locals budget" do
    -- workingLocalCeiling = 23 - 20 = 3; `local M` occupies one slot, so
    -- only the top two fields by read count are promoted.
    promotesWith
      LuaLimits {maxLocals = 23, maxUpvalues = 60}
      [__i|
        local M = {}
        M.a = 1
        M.b = 2
        M.c = 3
        M.f = function() return M.a + M.a + M.b + M.b + M.c end
        return { f = M.f }
      |]
      [__i|
        local M = {}
        local a = 1
        local b = 2
        M.c = 3
        M.f = function() return a + a + b + b + M.c end
        return { f = M.f }
      |]

  it "degrades to the module-table form when the locals budget is spent" do
    unchangedWith
      LuaLimits {maxLocals = 21, maxUpvalues = 60}
      [__i|
        local M = {}
        M.a = 1
        M.f = function(x) return M.a + x end
        return { f = M.f, a = M.a }
      |]

  it "demotes reads inside an over-budget function, keeping the local" do
    -- workingUpvalueCeiling = 8 - 5 = 3. The demoted fields are mirrored
    -- into the module table, and g still reads the chunk local `e`.
    promotesWith
      LuaLimits {maxLocals = 200, maxUpvalues = 8}
      [__i|
        local M = {}
        M.a = 1
        M.b = 2
        M.c = 3
        M.d = 4
        M.e = 5
        M.f = function()
          return M.a + M.a + M.a + M.b + M.b + M.c + M.c + M.d + M.e
        end
        M.g = function() return M.e + M.e end
        return { f = M.f, g = M.g }
      |]
      [__i|
        local M = {}
        local a = 1
        local b = 2
        M.b = b
        local c = 3
        local d = 4
        M.d = d
        local e = 5
        M.e = e
        local f = function()
          return a + a + a + M.b + M.b + c + c + M.d + M.e
        end
        local g = function() return e + e end
        return { f = f, g = g }
      |]

  it "accounts for the pass-through upvalues of intermediate functions" do
    -- The innermost function needs p and q on top of the promoted
    -- fields, and every intermediate function materializes its
    -- children's demands, so the fields demote level by level.
    promotesWith
      LuaLimits {maxLocals = 200, maxUpvalues = 8}
      [__i|
        local M = {}
        M.a = 1
        M.b = 2
        M.c = 3
        M.f = function(p)
          return function(q)
            return function(r)
              return M.a + M.b + M.c + p + q
            end
          end
        end
        return { f = M.f }
      |]
      [__i|
        local M = {}
        local a = 1
        M.a = a
        local b = 2
        M.b = b
        local c = 3
        M.c = c
        local f = function(p)
          return function(q)
            return function(r)
              return M.a + M.b + M.c + p + q
            end
          end
        end
        return { f = f }
      |]

  it "resolves a reference before its declaration as an outer reference" do
    -- Inside g the name v is not yet declared, so it resolves outside f
    -- (a global): it must not count toward g's upvalue demand, and no
    -- demotion happens at the ceiling of 3.
    promotesWith
      LuaLimits {maxLocals = 200, maxUpvalues = 8}
      [__i|
        local M = {}
        M.a = 1
        M.b = 2
        M.c = 3
        M.f = function()
          local g = function() return v + M.a + M.b + M.c end
          local v = 1
          return g() + v
        end
        return { f = M.f }
      |]
      [__i|
        local a = 1
        local b = 2
        local c = 3
        local f = function()
          local g = function() return v + a + b + c end
          local v = 1
          return g() + v
        end
        return { f = f }
      |]

  it "declines a binding whose name is used elsewhere in the chunk" do
    [__i|
      local M = {}
      M.a = 1
      M.f = function(x)
        local a = x
        return a + M.a + M.a
      end
      return { f = M.f }
    |]
      `promotesTo` [__i|
        local M = {}
        M.a = 1
        local f = function(x)
          local a = x
          return a + M.a + M.a
        end
        return { f = f }
      |]

  it "leaves the chunk alone when the module table is unstable" do
    unchanged
      [__i|
        local M = {}
        M.a = 1
        M.f = function(x)
          M.a = x
          return M.a
        end
        return { f = M.f }
      |]

  it "leaves a chunk without a module table alone" do
    unchanged
      [__i|
        local x = 1
        return { x = x }
      |]

  describe "keeps evaluation output intact under non-default limits" do
    -- End-to-end proof that the limits are honored by the real pipeline
    -- and that degrading to the module-table form preserves semantics: a
    -- golden module compiled with tight budgets must print exactly its
    -- hand-verified eval oracle.
    let modname = PS.ModuleName "Golden.GenericEqTwoTypes.Test"
        psOutputPath = $(mkRelDir "test/ps/output/")
        oracle =
          "test/ps/output/Golden.GenericEqTwoTypes.Test/eval/golden.txt"
        cases =
          [ ("a low locals budget", LuaLimits {maxLocals = 25, maxUpvalues = 60})
          , ("a low upvalue budget", LuaLimits {maxLocals = 200, maxUpvalues = 8})
          ]
    for_ cases \(caseName, limits) →
      it ("evaluates unchanged under " <> caseName) do
        uber ← compileCorefn (Tagged (Rel psOutputPath)) modname
        luaText ←
          compileIr (AsApplication modname (PS.Ident "main")) limits uber
        -- The tight locals budget must actually bite: the module table
        -- survives, proving the limits reached the pass.
        when (maxLocals limits < 200) $
          luaText `shouldSatisfy` Text.isInfixOf "local M = {}"
        expected ← decodeUtf8 <$> readFileBS oracle
        out ← withSystemTempFile "pslua-promote-e2e.lua" \path h → do
          hClose h
          writeFileText (toFilePath path) luaText
          (exitCode, out) ←
            readProcessInterleaved (fromString ("lua " <> toFilePath path))
          exitCode `shouldBe` ExitSuccess
          pure out
        normalizeOutput (decodeUtf8 out) `shouldBe` normalizeOutput expected

--------------------------------------------------------------------------------
-- Helper Functions ------------------------------------------------------------

render ∷ Lua.Chunk → Text
render =
  renderStrict . layoutPretty defaultLayoutOptions . Printer.printLuaChunk

promotesWith ∷ HasCallStack ⇒ LuaLimits → Text → Text → Expectation
promotesWith limits source expected =
  render (promoteChunk limits [name|M|] (unsafeParseStatements source))
    `shouldBe` render (unsafeParseStatements expected)

promotesTo ∷ HasCallStack ⇒ Text → Text → Expectation
promotesTo = promotesWith lua51Limits

unchangedWith ∷ HasCallStack ⇒ LuaLimits → Text → Expectation
unchangedWith limits source = promotesWith limits source source

unchanged ∷ HasCallStack ⇒ Text → Expectation
unchanged source = source `promotesTo` source

-- Mirrors the eval-golden normalization of the golden harness.
normalizeOutput ∷ Text → Text
normalizeOutput =
  unlines . filter (not . Text.null) . fmap Text.stripStart . lines
