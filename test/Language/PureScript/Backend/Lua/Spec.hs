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
