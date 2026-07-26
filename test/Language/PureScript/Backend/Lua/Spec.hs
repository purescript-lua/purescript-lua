{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Spec where

import Control.Monad.Oops (Variant)
import Control.Monad.Oops qualified as Oops
import Data.Tagged (Tagged (..))
import Data.Text qualified as Text
import Language.PureScript.Backend.IR qualified as IR
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.Lua qualified as Lua
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types qualified as Lua.Types
import Language.PureScript.Backend.Types (AppOrModule (AsModule))
import Path (relfile, toFilePath, (</>))
import Path.IO (getCurrentDir, withSystemTempDir)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldSatisfy)
import Test.Hspec.Expectations.Pretty (shouldBe)

spec ∷ Spec
spec = describe "Lua.fromUberModule" do
  it "does not wrap Abs-over-Let body in a scope IIFE" do
    rendered ← compileExportedExpr absWithLetBody
    rendered `shouldSatisfy` (not . Text.isInfixOf "(function()")

  it "does not wrap Abs-over-IfThenElse body in a scope IIFE" do
    rendered ← compileExportedExpr absWithIfBody
    rendered `shouldSatisfy` (not . Text.isInfixOf "(function()")

  it "lays a product-type constructor out positionally, without a tag" do
    rendered ← compileExportedExpr (ctorExpr IR.ProductType)
    rendered `shouldSatisfy` Text.isInfixOf "{ value0 }"
    rendered `shouldSatisfy` (not . Text.isInfixOf "M∷T.C")

  it "lays a sum-type constructor out positionally, tag string first" do
    rendered ← compileExportedExpr (ctorExpr IR.SumType)
    rendered `shouldSatisfy` Text.isInfixOf "{ \"M∷T.C\", value0 }"
    rendered `shouldSatisfy` (not . Text.isInfixOf "$ctor")

  it "parenthesises a call in the final constructor field" do
    rendered ← compileExportedExpr ctorAppFieldExpr
    -- The call is the last positional row, so it is wrapped to one value
    -- rather than splicing its results into the table.
    rendered `shouldSatisfy` Text.isInfixOf "{ \"M∷T.C\", (f(x)) }"

  it "lowers a tag read to index [1]" do
    rendered ← compileExportedExpr (absN ["x"] (IR.reflectCtor (ref "x")))
    rendered `shouldSatisfy` Text.isInfixOf "x[1]"

  it "offsets a sum-type field read past the tag slot" do
    rendered ←
      compileExportedExpr
        (absN ["x"] (IR.dataArgumentByIndex IR.SumType 0 (ref "x")))
    rendered `shouldSatisfy` Text.isInfixOf "x[2]"

  it "reads a product-type field with no tag offset" do
    rendered ←
      compileExportedExpr
        (absN ["x"] (IR.dataArgumentByIndex IR.ProductType 0 (ref "x")))
    rendered `shouldSatisfy` Text.isInfixOf "x[1]"

  it "emits one n-ary Lua call for a multi-argument AppN" do
    rendered ← compileExportedExpr naryCall
    -- A single call passing every argument, not a curried f(a)(b)(c) spine.
    rendered `shouldSatisfy` Text.isInfixOf "f(a, b, c)"
    rendered `shouldSatisfy` (not . Text.isInfixOf "f(a)(b)(c)")

  it "emits one n-ary Lua function for a multi-parameter AbsN" do
    rendered ← compileExportedExpr naryAbs
    -- One function binding both parameters, not a curried chain.
    rendered `shouldSatisfy` Text.isInfixOf "function(a, b)"
    rendered `shouldSatisfy` (not . Text.isInfixOf "function(a)")

  it "drops the trailing run of unused AbsN parameters" do
    rendered ← compileExportedExpr naryAbsTrailingUnused
    rendered `shouldSatisfy` Text.isInfixOf "function(a)"
    rendered `shouldSatisfy` (not . Text.isInfixOf "function(a,")

  it "elides the trailing run of Prim.undefined arguments" do
    rendered ← compileExportedExpr (naryCallOn [ref "a", primUndefined])
    rendered `shouldSatisfy` Text.isInfixOf "f(a)"

  it "lowers a non-trailing Prim.undefined argument to nil" do
    rendered ← compileExportedExpr (naryCallOn [primUndefined, ref "b"])
    rendered `shouldSatisfy` Text.isInfixOf "f(nil, b)"

  -- See Note [Multi-value results] in ...Backend.IR.Types
  describe "multi-value results (#206)" do
    it "lowers a Values tail to a multi-value return" do
      rendered ← compileExportedExpr multiValueTail
      rendered `shouldSatisfy` Text.isInfixOf "return a, b"

    it "parenthesises a call in the last Values slot" do
      rendered ←
        compileExportedExpr $
          absN ["a", "f", "x"] $
            IR.values (ref "a" :| [IR.application (ref "f") (ref "x")])
      rendered `shouldSatisfy` Text.isInfixOf "return a, (f(x))"

    it "pushes a Values tail into both IfThenElse branches" do
      rendered ←
        compileExportedExpr $
          absN ["c", "a", "b"] $
            IR.ifThenElse
              (ref "c")
              (IR.values (ref "a" :| [ref "b"]))
              (IR.values (ref "b" :| [ref "a"]))
      rendered `shouldSatisfy` Text.isInfixOf "return a, b"
      rendered `shouldSatisfy` Text.isInfixOf "return b, a"

    it "lowers LetValues to a multi-name local" do
      rendered ← compileExportedExpr (letValuesExpr [pn "a", pn "b"])
      rendered `shouldSatisfy` Text.isInfixOf "local a, b = f(s)"

    it "drops the trailing unused run of LetValues binders" do
      rendered ←
        compileExportedExpr (letValuesExpr [pn "a", IR.ParamUnused IR.noAnn])
      rendered `shouldSatisfy` Text.isInfixOf "local a = f(s)"
      rendered `shouldSatisfy` (not . Text.isInfixOf "local a,")

  describe "loopification (#181)" do
    it "lowers a top-level self-recursive tail call to a while loop" do
      rendered ← compileRecBinding (selfTailLoop topSelf)
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      rendered `shouldSatisfy` Text.isInfixOf "acc, n = n, acc"
      rendered `shouldSatisfy` (not . Text.isInfixOf "M.Test_Loopify_go(n, acc)")

    it "loopifies a Let-bound recursive group the same way" do
      rendered ← compileExportedExpr letRecLoop
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      rendered `shouldSatisfy` Text.isInfixOf "acc, n = n, acc"

    it "keeps a non-tail self-call a real call" do
      rendered ← compileRecBinding (selfNonTailCall topSelf)
      rendered `shouldSatisfy` (not . Text.isInfixOf "while true do")

    it "does not loopify when a closure captures a parameter" do
      rendered ← compileRecBinding (selfTailLoopCapturing topSelf)
      rendered `shouldSatisfy` (not . Text.isInfixOf "while true do")

    it "rewrites both tail branches and keeps the non-tail one" do
      rendered ← compileRecBinding (mixedTailCalls topSelf)
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      rendered `shouldSatisfy` Text.isInfixOf "M.Test_Loopify_go(acc, acc)"

    it "drops a pure surplus argument facing a dropped parameter" do
      rendered ← compileRecBinding (surplusArg topSelf (ref "acc"))
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      rendered `shouldSatisfy` Text.isInfixOf "acc = q"
      rendered `shouldSatisfy` (not . Text.isInfixOf "acc = q, acc")

    it "declines on an effectful surplus argument" do
      rendered ←
        compileRecBinding
          (surplusArg topSelf (IR.App IR.noAnn (ref "f") (ref "acc")))
      rendered `shouldSatisfy` (not . Text.isInfixOf "while true do")

    it "pads elided trailing arguments with nil" do
      rendered ← compileRecBinding (shortCall topSelf (ref "x"))
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      rendered `shouldSatisfy` Text.isInfixOf "acc, n = x, nil"

    it "declines to pad after a multi-value argument" do
      rendered ←
        compileRecBinding
          (shortCall topSelf (IR.App IR.noAnn (ref "g") (ref "x")))
      rendered `shouldSatisfy` (not . Text.isInfixOf "while true do")

  describe "loopification of mutual recursion (#234)" do
    it "lowers a mutual pair to a single while-true dispatcher" do
      rendered ←
        compileMutualGroup (("ping", mutualPing) :| [("pong", mutualPong)])
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      -- Sibling transitions set the selector and all slots at once.
      rendered `shouldSatisfy` Text.isInfixOf "_S_sel0, _S_a1, _S_a2 = 2, n, acc"
      rendered `shouldSatisfy` Text.isInfixOf "_S_sel0, _S_a1, _S_a2 = 1, b, a"
      -- Each branch rebinds its parameters from the shared slots.
      rendered `shouldSatisfy` Text.isInfixOf "local acc, n = _S_a1, _S_a2"
      -- Entry wrappers delegate to the dispatcher…
      rendered
        `shouldSatisfy` Text.isInfixOf
          "return M.Test_Loopify_ping_S_loop(1, acc, n)"
      rendered
        `shouldSatisfy` Text.isInfixOf
          "return M.Test_Loopify_ping_S_loop(2, a, b)"
      -- …and no cross-call between the members remains.
      rendered `shouldSatisfy` (not . Text.isInfixOf "M.Test_Loopify_pong(")

    it "keeps a group without a spine tail-call cycle untouched" do
      rendered ←
        compileMutualGroup (("ping", nonTailPing) :| [("pong", mutualPong)])
      rendered `shouldSatisfy` (not . Text.isInfixOf "while true do")
      rendered `shouldSatisfy` (not . Text.isInfixOf "_S_loop")
      rendered `shouldSatisfy` Text.isInfixOf "M.Test_Loopify_pong(n, acc)"

    it "pads a narrower member's transition with nil" do
      rendered ←
        compileMutualGroup (("uno", unoCallsDos) :| [("dos", dosCallsUno)])
      rendered `shouldSatisfy` Text.isInfixOf "_S_sel0, _S_a1, _S_a2 = 2, n, 1"
      rendered `shouldSatisfy` Text.isInfixOf "_S_sel0, _S_a1, _S_a2 = 1, a, nil"

    it "dispatches a Let-bound mutual pair through a local dispatcher" do
      rendered ← compileExportedExpr letMutualLoop
      rendered `shouldSatisfy` Text.isInfixOf "local tick_S_loop"
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      rendered `shouldSatisfy` Text.isInfixOf "_S_sel0, _S_a1, _S_a2 = 2, k, c"
      rendered `shouldSatisfy` Text.isInfixOf "return tick_S_loop(1, c, k)"

    it "leaves a member outside the cycle referencing dispatched entries" do
      rendered ←
        compileMutualGroup
          (("wA", waCallsWb) :| [("wB", wbCallsWa), ("pw", curriedOverWa)])
      rendered `shouldSatisfy` Text.isInfixOf "while true do"
      -- The curried member keeps its reference; it now hits wA's entry
      -- wrapper, whose binding survives under the original name.
      rendered `shouldSatisfy` Text.isInfixOf "return M.Test_Loopify_wA(x, y)"
      rendered `shouldSatisfy` (not . Text.isInfixOf "M.Test_Loopify_wB(")

  describe "join points (#234)" do
    it "fuses a Let-bound recursive worker into the enclosing body" do
      rendered ← compileExportedExpr letRecLoop
      -- The function shell and its entry call are gone; the entry
      -- became a parameter assignment falling through into the loop.
      rendered `shouldSatisfy` (not . Text.isInfixOf "local go")
      rendered `shouldSatisfy` (not . Text.isInfixOf "go(")
      rendered `shouldSatisfy` Text.isInfixOf "local acc, n"
      rendered `shouldSatisfy` Text.isInfixOf "acc, n = 0, m"
      rendered `shouldSatisfy` Text.isInfixOf "while true do"

    it "fuses a non-recursive continuation called from two branches" do
      rendered ← compileExportedExpr joinContinuation
      rendered `shouldSatisfy` (not . Text.isInfixOf "finish")
      rendered `shouldSatisfy` Text.isInfixOf "r = a"
      rendered `shouldSatisfy` Text.isInfixOf "r = b"
      rendered `shouldSatisfy` Text.isInfixOf "return g(r)"
      -- No self-recursion, so no loop either.
      rendered `shouldSatisfy` (not . Text.isInfixOf "while true do")

    it "fuses chained join points" do
      rendered ← compileExportedExpr chainedJoins
      rendered `shouldSatisfy` (not . Text.isInfixOf "k1")
      rendered `shouldSatisfy` (not . Text.isInfixOf "k2")
      rendered `shouldSatisfy` Text.isInfixOf "return g(b)"

    it "keeps a helper that escapes into a closure" do
      rendered ← compileExportedExpr escapingHelper
      rendered `shouldSatisfy` Text.isInfixOf "local esc"
      rendered `shouldSatisfy` Text.isInfixOf "esc(m)"

    it "keeps a helper with a non-tail call site" do
      rendered ← compileExportedExpr nonTailHelper
      rendered `shouldSatisfy` Text.isInfixOf "local h"
      rendered `shouldSatisfy` Text.isInfixOf "h(n)"

    it "declines when a spine leaf returns a call" do
      rendered ← compileExportedExpr callLeafBeside
      -- Fusing would bury the sibling `return f(n)` mid-chunk, robbing
      -- the enclosing binding's own loopification of a tail position.
      rendered `shouldSatisfy` Text.isInfixOf "local k"
      rendered `shouldSatisfy` Text.isInfixOf "k(n)"

  describe "foreign export check (#249)" do
    it "rejects a declared foreign name missing from the FFI exports" do
      result ← compileForeignModule "return { foo = 42 }" ["foo", "bar"]
      case result of
        Left (Lua.ForeignExportsMissing modname missing) → do
          modname `shouldBe` testModuleName
          toList missing `shouldBe` [IR.Name "bar"]
        Left err →
          expectationFailure ("Unexpected error: " <> show err)
        Right _chunk →
          expectationFailure
            "Expected ForeignExportsMissing, but compilation succeeded"

    it "accepts an FFI file that exports every declared name" do
      result ← compileForeignModule "return { foo = 42, bar = 1 }" ["foo"]
      result `shouldSatisfy` isRight

compileExportedExpr ∷ IR.Exp → IO Text
compileExportedExpr expr =
  compileUberModule
    UberModule
      { uberModuleBindings = []
      , uberModuleForeigns = []
      , uberModuleExports = [(IR.Name "value", expr)]
      }

{- | Compile a module with a single self-recursive top-level binding
@go@ (a 'IR.RecursiveGroup' of one member).
-}
compileRecBinding ∷ IR.Exp → IO Text
compileRecBinding expr =
  compileUberModule
    UberModule
      { uberModuleBindings =
          [ IR.RecursiveGroup
              ((IR.QName testModuleName (IR.Name "go"), expr) :| [])
          ]
      , uberModuleForeigns = []
      , uberModuleExports = [(IR.Name "value", topSelf)]
      }

{- | Compile a module with one top-level 'IR.RecursiveGroup' holding the
given members, the first of which is exported.
-}
compileMutualGroup ∷ NonEmpty (Text, IR.Exp) → IO Text
compileMutualGroup members =
  compileUberModule
    UberModule
      { uberModuleBindings =
          [ IR.RecursiveGroup $
              members <&> \(name, expr) →
                (IR.QName testModuleName (IR.Name name), expr)
          ]
      , uberModuleForeigns = []
      , uberModuleExports = [(IR.Name "value", topRef (fst (head members)))]
      }

testModuleName ∷ IR.ModuleName
testModuleName = IR.ModuleName "Test.Loopify"

compileUberModule ∷ UberModule → IO Text
compileUberModule uberModule = do
  foreignPath ← Tagged <$> getCurrentDir
  result ←
    runExceptT
      ( Lua.fromUberModule
          foreignPath
          (Tagged False)
          (AsModule testModuleName)
          uberModule
          ∷ ExceptT (Variant '[Lua.Error]) IO Lua.Types.Chunk
      )
  case result of
    Left _err → expectationFailure "Lua.fromUberModule failed" >> pure ""
    Right chunk →
      pure . renderStrict $
        layoutPretty defaultLayoutOptions (Printer.printLuaChunk chunk)

{- | Compile a module whose only content is a foreign import carrying
@declaredNames@, resolved against an FFI file with the given source text.
Mirrors the shape 'Language.PureScript.Backend.IR.Linker.foreignBindings'
emits (see Note [Foreign bindings structure emitted by the Linker]).
-}
compileForeignModule ∷ String → [Text] → IO (Either Lua.Error Lua.Types.Chunk)
compileForeignModule ffiSource declaredNames =
  withSystemTempDir "foreigns" \foreigns → do
    let path = toFilePath (foreigns </> [relfile|Foo.lua|])
    writeFile path ffiSource
    let uberModule =
          UberModule
            { uberModuleBindings = []
            , uberModuleForeigns =
                [
                  ( IR.QName testModuleName (IR.Name "foreign")
                  , IR.ForeignImport
                      IR.noAnn
                      testModuleName
                      path
                      [(IR.noAnn, IR.Name name) | name ← declaredNames]
                  )
                ]
            , uberModuleExports = []
            }
    Oops.runOops $
      ( Right
          <$> Lua.fromUberModule
            (Tagged foreigns)
            (Tagged False)
            (AsModule testModuleName)
            uberModule
      )
        & Oops.catch \(e ∷ Lua.Error) → pure (Left e)

absWithLetBody ∷ IR.Exp
absWithLetBody =
  IR.Abs
    IR.noAnn
    (IR.ParamNamed IR.noAnn (IR.Name "x"))
    ( IR.Let
        IR.noAnn
        ( IR.Standalone
            ( IR.noAnn
            , IR.Name "y"
            , IR.App
                IR.noAnn
                (IR.Ref IR.noAnn (IR.Local (IR.Name "f")))
                (IR.Ref IR.noAnn (IR.Local (IR.Name "x")))
            )
            :| []
        )
        (IR.Ref IR.noAnn (IR.Local (IR.Name "y")))
    )

absWithIfBody ∷ IR.Exp
absWithIfBody =
  IR.Abs
    IR.noAnn
    (IR.ParamNamed IR.noAnn (IR.Name "x"))
    ( IR.IfThenElse
        IR.noAnn
        (IR.Ref IR.noAnn (IR.Local (IR.Name "p")))
        (IR.Ref IR.noAnn (IR.Local (IR.Name "x")))
        (IR.LiteralInt IR.noAnn 0)
    )

-- @f(a, b, c)@: one call, three arguments, head is a plain reference.
naryCall ∷ IR.Exp
naryCall = naryCallOn [ref "a", ref "b", ref "c"]

naryCallOn ∷ [IR.Exp] → IR.Exp
naryCallOn = \case
  arg : args → IR.AppN IR.noAnn (ref "f") (arg :| args)
  [] → error "naryCallOn: needs at least one argument"

ref ∷ Text → IR.Exp
ref = IR.Ref IR.noAnn . IR.Local . IR.Name

primUndefined ∷ IR.Exp
primUndefined =
  IR.Ref IR.noAnn (IR.Imported (IR.ModuleName "Prim") (IR.Name "undefined"))

-- @function(a, b) return a end@: one function, two parameters.
naryAbs ∷ IR.Exp
naryAbs =
  IR.AbsN
    IR.noAnn
    ( IR.ParamNamed IR.noAnn (IR.Name "a")
        :| [IR.ParamNamed IR.noAnn (IR.Name "b")]
    )
    (ref "a")

-- @function(a) return a end@: the trailing unused parameters are dropped.
naryAbsTrailingUnused ∷ IR.Exp
naryAbsTrailingUnused =
  IR.AbsN
    IR.noAnn
    ( IR.ParamNamed IR.noAnn (IR.Name "a")
        :| [IR.ParamUnused IR.noAnn, IR.ParamUnused IR.noAnn]
    )
    (ref "a")

-- Loopification fixtures ------------------------------------------------------

-- | The top-level binding @go@ referencing itself.
topSelf ∷ IR.Exp
topSelf = IR.Ref IR.noAnn (IR.Imported testModuleName (IR.Name "go"))

{- | @go acc n = if p then acc else go n acc@ — the argument swap pins
the simultaneity of the parameter reassignment.
-}
selfTailLoop ∷ IR.Exp → IR.Exp
selfTailLoop self =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "acc")
      (IR.AppN IR.noAnn self (ref "n" :| [ref "acc"]))

{- | @go acc n = if p then acc else f (go n acc)@ — the self-call is an
argument, not a tail call.
-}
selfNonTailCall ∷ IR.Exp → IR.Exp
selfNonTailCall self =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "acc")
      ( IR.App
          IR.noAnn
          (ref "f")
          (IR.AppN IR.noAnn self (ref "n" :| [ref "acc"]))
      )

{- | @go acc n = if p then acc else go (\\r → acc n) acc@ — the closure
argument captures the loop-carried parameters.
-}
selfTailLoopCapturing ∷ IR.Exp → IR.Exp
selfTailLoopCapturing self =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "acc")
      ( IR.AppN
          IR.noAnn
          self
          ( IR.Abs
              IR.noAnn
              (IR.ParamNamed IR.noAnn (IR.Name "r"))
              (IR.App IR.noAnn (ref "acc") (ref "n"))
              :| [ref "acc"]
          )
      )

{- | @go acc n = if p then go n acc else f (go acc acc)@ — a tail and a
non-tail self-call side by side.
-}
mixedTailCalls ∷ IR.Exp → IR.Exp
mixedTailCalls self =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (IR.App IR.noAnn (ref "p") (ref "n"))
      (IR.AppN IR.noAnn self (ref "n" :| [ref "acc"]))
      ( IR.App
          IR.noAnn
          (ref "f")
          (IR.AppN IR.noAnn self (ref "acc" :| [ref "acc"]))
      )

-- | @\\m → let go acc n = … in go 0 m@ with a self-recursive local @go@.
letRecLoop ∷ IR.Exp
letRecLoop =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "m")) $
    IR.Let
      IR.noAnn
      ( IR.RecursiveGroup
          ( ( IR.noAnn
            , IR.Name "go"
            , selfTailLoop (IR.Ref IR.noAnn (IR.Local (IR.Name "go")))
            )
              :| []
          )
          :| []
      )
      ( IR.AppN
          IR.noAnn
          (IR.Ref IR.noAnn (IR.Local (IR.Name "go")))
          (IR.LiteralInt IR.noAnn 0 :| [ref "m"])
      )

{- | @go acc _ = if p then acc else go q \<arg\>@ — the second parameter
is unused (and dropped by the Lua backend), so the self-call passes one
value more than the function has variables to assign.
-}
surplusArg ∷ IR.Exp → IR.Exp → IR.Exp
surplusArg self arg =
  IR.AbsN
    IR.noAnn
    (IR.ParamNamed IR.noAnn (IR.Name "acc") :| [IR.ParamUnused IR.noAnn])
    ( IR.IfThenElse
        IR.noAnn
        (ref "p")
        (ref "acc")
        (IR.AppN IR.noAnn self (ref "q" :| [arg]))
    )

{- | @go acc n = if p then acc else go \<arg\> Prim.undefined@ — the
trailing undefined argument is elided from the call, leaving it one
value short of the parameter list.
-}
shortCall ∷ IR.Exp → IR.Exp → IR.Exp
shortCall self arg =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "acc")
      (IR.AppN IR.noAnn self (arg :| [primUndefined]))

-- Mutual loopification fixtures (#234) ----------------------------------------

-- | A reference to the given top-level binding of the test module.
topRef ∷ Text → IR.Exp
topRef = IR.Ref IR.noAnn . IR.Imported testModuleName . IR.Name

{- | @ping acc n = if p then acc else pong n acc@ — tail-calls its
sibling with the arguments swapped.
-}
mutualPing ∷ IR.Exp
mutualPing =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "acc")
      (IR.AppN IR.noAnn (topRef "pong") (ref "n" :| [ref "acc"]))

-- | @pong a b = if q then b else ping b a@.
mutualPong ∷ IR.Exp
mutualPong =
  absN ["a", "b"] $
    IR.IfThenElse
      IR.noAnn
      (ref "q")
      (ref "b")
      (IR.AppN IR.noAnn (topRef "ping") (ref "b" :| [ref "a"]))

{- | @ping acc n = if p then acc else f (pong n acc)@ — the sibling call
is an operand, so the pair has no tail-call cycle.
-}
nonTailPing ∷ IR.Exp
nonTailPing =
  absN ["acc", "n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "acc")
      ( IR.App
          IR.noAnn
          (ref "f")
          (IR.AppN IR.noAnn (topRef "pong") (ref "n" :| [ref "acc"]))
      )

-- | @uno n = if p then n else dos n 1@ — the narrower member.
unoCallsDos ∷ IR.Exp
unoCallsDos =
  absN ["n"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "n")
      ( IR.AppN
          IR.noAnn
          (topRef "dos")
          (ref "n" :| [IR.LiteralInt IR.noAnn 1])
      )

-- | @dos a b = if q then b else uno a@ — transitions back one slot short.
dosCallsUno ∷ IR.Exp
dosCallsUno =
  absN ["a", "b"] $
    IR.IfThenElse
      IR.noAnn
      (ref "q")
      (ref "b")
      (IR.AppN IR.noAnn (topRef "uno") (ref "a" :| []))

-- | @\\m → let tick c k = … tock …; tock d j = … tick … in tick 0 m@.
letMutualLoop ∷ IR.Exp
letMutualLoop =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "m")) $
    IR.Let
      IR.noAnn
      ( IR.RecursiveGroup
          ( ( IR.noAnn
            , IR.Name "tick"
            , absN ["c", "k"] $
                IR.IfThenElse
                  IR.noAnn
                  (ref "p")
                  (ref "c")
                  (IR.AppN IR.noAnn (ref "tock") (ref "k" :| [ref "c"]))
            )
              :| [
                   ( IR.noAnn
                   , IR.Name "tock"
                   , absN ["d", "j"] $
                       IR.IfThenElse
                         IR.noAnn
                         (ref "q")
                         (ref "d")
                         (IR.AppN IR.noAnn (ref "tick") (ref "j" :| [ref "d"]))
                   )
                 ]
          )
          :| []
      )
      ( IR.AppN
          IR.noAnn
          (ref "tick")
          (IR.LiteralInt IR.noAnn 0 :| [ref "m"])
      )

-- | @wA x1 y1 = if p then x1 else wB y1 x1@.
waCallsWb ∷ IR.Exp
waCallsWb =
  absN ["x1", "y1"] $
    IR.IfThenElse
      IR.noAnn
      (ref "p")
      (ref "x1")
      (IR.AppN IR.noAnn (topRef "wB") (ref "y1" :| [ref "x1"]))

-- | @wB x2 y2 = if q then x2 else wA y2 x2@.
wbCallsWa ∷ IR.Exp
wbCallsWa =
  absN ["x2", "y2"] $
    IR.IfThenElse
      IR.noAnn
      (ref "q")
      (ref "x2")
      (IR.AppN IR.noAnn (topRef "wA") (ref "y2" :| [ref "x2"]))

{- | @pw x = \\y → wA x y@ — references a dispatched member from under a
nested lambda, the shape of an uncurrying wrapper left in the group.
-}
curriedOverWa ∷ IR.Exp
curriedOverWa =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "x")) $
    IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "y")) $
      IR.AppN IR.noAnn (topRef "wA") (ref "x" :| [ref "y"])

-- Join-point fixtures (#234) --------------------------------------------------

{- | @\\n → let finish r = g r in if c then finish a else finish b@ — a
non-recursive continuation tail-called from both branches.
-}
joinContinuation ∷ IR.Exp
joinContinuation =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "n")) $
    IR.Let
      IR.noAnn
      ( IR.Standalone
          ( IR.noAnn
          , IR.Name "finish"
          , absN ["r"] (IR.App IR.noAnn (ref "g") (ref "r"))
          )
          :| []
      )
      ( IR.IfThenElse
          IR.noAnn
          (ref "c")
          (IR.AppN IR.noAnn (ref "finish") (ref "a" :| []))
          (IR.AppN IR.noAnn (ref "finish") (ref "b" :| []))
      )

{- | @\\n → let k2 b = g b; k1 a = k2 a in k1 n@ — the body enters k1,
whose own tail position enters k2; both fuse, one per round.
-}
chainedJoins ∷ IR.Exp
chainedJoins =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "n")) $
    IR.Let
      IR.noAnn
      ( IR.Standalone
          ( IR.noAnn
          , IR.Name "k2"
          , absN ["b"] (IR.App IR.noAnn (ref "g") (ref "b"))
          )
          :| [ IR.Standalone
                 ( IR.noAnn
                 , IR.Name "k1"
                 , absN ["a"] (IR.AppN IR.noAnn (ref "k2") (ref "a" :| []))
                 )
             ]
      )
      (IR.AppN IR.noAnn (ref "k1") (ref "n" :| []))

{- | @\\n → let esc a = a in \\m → esc m@ — the helper is referenced from
inside the returned closure, so it must keep its function shell.
-}
escapingHelper ∷ IR.Exp
escapingHelper =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "n")) $
    IR.Let
      IR.noAnn
      ( IR.Standalone (IR.noAnn, IR.Name "esc", absN ["a"] (ref "a"))
          :| []
      )
      ( IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "m")) $
          IR.AppN IR.noAnn (ref "esc") (ref "m" :| [])
      )

-- | @\\n → let h a = a in g (h n)@ — the helper's call is an operand.
nonTailHelper ∷ IR.Exp
nonTailHelper =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "n")) $
    IR.Let
      IR.noAnn
      ( IR.Standalone (IR.noAnn, IR.Name "h", absN ["a"] (ref "a"))
          :| []
      )
      ( IR.App
          IR.noAnn
          (ref "g")
          (IR.AppN IR.noAnn (ref "h") (ref "n" :| []))
      )

{- | @\\n → let k a = a in if c then k n else f n@ — one branch enters
the join point, the other tail-calls something else.
-}
callLeafBeside ∷ IR.Exp
callLeafBeside =
  IR.Abs IR.noAnn (IR.ParamNamed IR.noAnn (IR.Name "n")) $
    IR.Let
      IR.noAnn
      ( IR.Standalone (IR.noAnn, IR.Name "k", absN ["a"] (ref "a"))
          :| []
      )
      ( IR.IfThenElse
          IR.noAnn
          (ref "c")
          (IR.AppN IR.noAnn (ref "k") (ref "n" :| []))
          (IR.AppN IR.noAnn (ref "f") (ref "n" :| []))
      )

-- Multi-value fixtures (#206) -------------------------------------------------

-- | @function(a, b) return a, b end@ — a result worker's shape.
multiValueTail ∷ IR.Exp
multiValueTail = absN ["a", "b"] (IR.values (ref "a" :| [ref "b"]))

pn ∷ Text → IR.Parameter IR.Ann
pn = IR.ParamNamed IR.noAnn . IR.Name

{- | @function(s) local \<binders\> = f(s) return a end@ — the shape a
rewritten deconstructing call site lowers to.
-}
letValuesExpr ∷ [IR.Parameter IR.Ann] → IR.Exp
letValuesExpr binders = case binders of
  p : ps →
    absN ["s"] $
      IR.letValues
        (p :| ps)
        (IR.AppN IR.noAnn (ref "f") (ref "s" :| []))
        (ref "a")
  [] → error "letValuesExpr: needs at least one binder"

absN ∷ [Text] → IR.Exp → IR.Exp
absN names body = case names of
  n : ns →
    IR.AbsN
      IR.noAnn
      (IR.ParamNamed IR.noAnn . IR.Name <$> (n :| ns))
      body
  [] → error "absN: needs at least one parameter"

{- | An arity-1 constructor as a manifest lambda over the saturated 'Ctor'
of its parameter — the shape 'mkConstructor' emits — so the codegen tests
exercise the in-place 'Ctor' table build inside the function body.
-}
ctorExpr ∷ IR.AlgebraicType → IR.Exp
ctorExpr algebraicTy =
  absN ["value0"] $
    IR.ctor
      algebraicTy
      (IR.ModuleName "M")
      (IR.TyName "T")
      (IR.CtorName "C")
      [ref "value0"]

{- | A constructor whose only field is a function call @f x@, so the final
positional row is a multi-valued expression that must be parenthesised to
one value (see 'Language.PureScript.Backend.Lua.parenLastMultiValued').
-}
ctorAppFieldExpr ∷ IR.Exp
ctorAppFieldExpr =
  absN ["f", "x"] $
    IR.ctor
      IR.SumType
      (IR.ModuleName "M")
      (IR.TyName "T")
      (IR.CtorName "C")
      [IR.application (ref "f") (ref "x")]
