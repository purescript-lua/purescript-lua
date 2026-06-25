{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Run.Spec where

import Language.PureScript.Backend.Lua.Fixture qualified as Fixture
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Run (runChunk)
import Language.PureScript.Backend.Lua.Types qualified as Lua
import System.Exit (ExitCode (..))
import Test.Hspec (Spec, describe, it, shouldBe)

spec ∷ Spec
spec = describe "Lua.Run.runChunk (powers `spago run`)" do
  it "runs a well-formed chunk through `lua` and reports success" do
    -- `return print("…")` is a valid top-level Lua chunk; lua exits 0.
    code ← runChunk [Lua.return (call [Lua.name|print|] [Lua.String "run-ok"])]
    code `shouldBe` ExitSuccess

  it "propagates the lua process exit code" do
    -- `os.exit(3)` makes the interpreter exit with code 3; the wrapper must
    -- forward it verbatim rather than swallowing it.
    code ← runChunk [Lua.return (osExit 3)]
    code `shouldBe` ExitFailure 3

  it "PSLUA_runtime_lazy memoizes: the initializer runs at most once" do
    -- Define the runtime-lazy fixture, build a lazy value whose initializer
    -- bumps a counter, force it twice, and exit 0 only if the initializer ran
    -- exactly once. A non-memoizing fixture runs it on every force and exits 1.
    code ←
      runChunk
        [ Fixture.runtimeLazy
        , Lua.ForeignSourceStat . unlines $
            [ "local count = 0"
            , "local lazy = "
                <> Lua.toText Fixture.runtimeLazyName
                <> "(\"x\")(function() count = count + 1 return {} end)"
            , "lazy(1)"
            , "lazy(2)"
            , "os.exit(count == 1 and 0 or 1)"
            ]
        ]
    code `shouldBe` ExitSuccess
 where
  call ∷ Lua.Name → [Lua.Exp] → Lua.Exp
  call fn = Lua.functionCall (Lua.varName fn)

  osExit ∷ Integer → Lua.Exp
  osExit n =
    Lua.functionCall
      (Lua.varField (Lua.varName [Lua.name|os|]) [Lua.name|exit|])
      [Lua.Integer n]
