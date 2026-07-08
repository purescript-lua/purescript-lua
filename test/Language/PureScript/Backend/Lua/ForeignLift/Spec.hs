module Language.PureScript.Backend.Lua.ForeignLift.Spec where

import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( PrimOp (..)
  , abstraction
  , eq
  , ifThenElse
  , paramNamed
  , primBinOp
  , primNot
  , refLocal
  )
import Language.PureScript.Backend.Lua.ForeignLift (allowlist, liftExport)
import Language.PureScript.Backend.Lua.Linker.Foreign
  ( Source
  , interpretForeignModule
  )
import Language.PureScript.Backend.Lua.Parser (parseChunk, renderParseError)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)

spec ∷ Spec
spec = describe "Foreign lift (#178)" do
  describe "lifts the pure return-tree subset" do
    it "lifts a curried binary-operator export" do
      liftExport
        (source "return { intAdd = function(x) return function(y) return x + y end end }")
        (Name "intAdd")
        `shouldBe` Just
          ( abstraction (paramNamed (Name "x")) $
              abstraction (paramNamed (Name "y")) $
                primBinOp PrimAdd (refLocal (Name "x")) (refLocal (Name "y"))
          )

    it "maps == onto the Eq node and inlines a header local alias" do
      -- The `refEq` family: exports alias a header `local`, which lifts by
      -- inlining. `==` becomes the existing Eq node, not a primop.
      let src =
            "local refEq = function(r1) return function(r2) return r1 == r2 end end\n"
              <> "return { eqIntImpl = (refEq) }"
      liftExport (source src) (Name "eqIntImpl")
        `shouldBe` Just
          ( abstraction (paramNamed (Name "r1")) $
              abstraction (paramNamed (Name "r2")) $
                eq (refLocal (Name "r1")) (refLocal (Name "r2"))
          )

    it "lifts an if/elseif/else tree through a header local (ordIntImpl)" do
      let src =
            "local cmp = function(lt) return function(eq) return function(gt) "
              <> "return function(x) return function(y) "
              <> "if x < y then return lt elseif x == y then return eq "
              <> "else return gt end "
              <> "end end end end end\n"
              <> "return { ordIntImpl = (cmp) }"
          lt = Name "lt"
          eqName = Name "eq"
          gt = Name "gt"
          x = Name "x"
          y = Name "y"
          body =
            ifThenElse
              (primBinOp PrimLt (refLocal x) (refLocal y))
              (refLocal lt)
              ( ifThenElse
                  (eq (refLocal x) (refLocal y))
                  (refLocal eqName)
                  (refLocal gt)
              )
          expected =
            abstraction (paramNamed lt) $
              abstraction (paramNamed eqName) $
                abstraction (paramNamed gt) $
                  abstraction (paramNamed x) $
                    abstraction (paramNamed y) body
      liftExport (source src) (Name "ordIntImpl") `shouldBe` Just expected

    it "lifts logical not" do
      liftExport
        (source "return { boolNot = function(b) return not b end }")
        (Name "boolNot")
        `shouldBe` Just (abstraction (paramNamed (Name "b")) (primNot (refLocal (Name "b"))))

    it "lifts string concatenation" do
      liftExport
        ( source
            "return { concatString = function(s1) return function(s2) return s1 .. s2 end end }"
        )
        (Name "concatString")
        `shouldBe` Just
          ( abstraction (paramNamed (Name "s1")) $
              abstraction (paramNamed (Name "s2")) $
                primBinOp PrimConcat (refLocal (Name "s1")) (refLocal (Name "s2"))
          )

  describe "declines everything outside the subset" do
    it "declines a multi-parameter function (would misapply when curried)" do
      liftExport (source "return { f = function(x, y) return x + y end }") (Name "f")
        `shouldSatisfy` isNothing

    it "declines a body with a table index" do
      liftExport (source "return { f = function(xs) return xs[1] end }") (Name "f")
        `shouldSatisfy` isNothing

    it "declines a body that is not a pure return tree" do
      let src =
            "return { f = function(xs) local i = 1 while i < 10 do i = i + 1 end return i end }"
      liftExport (source src) (Name "f") `shouldSatisfy` isNothing

    it "declines an if without an else (falls through to nil)" do
      liftExport
        (source "return { f = function(x) if x then return x end end }")
        (Name "f")
        `shouldSatisfy` isNothing

    it "declines a missing export" do
      liftExport (source "return { a = function(x) return x end }") (Name "b")
        `shouldSatisfy` isNothing

  describe "allowlist" do
    it "lists the arithmetic/comparison/boolean/concat core" do
      Set.member (qname "Data.Semiring" "intAdd") allowlist `shouldBe` True
      Set.member (qname "Data.Ord" "ordIntImpl") allowlist `shouldBe` True
      Set.member (qname "Data.Eq" "refEq") allowlist `shouldBe` True
      Set.member (qname "Data.Semigroup" "concatString") allowlist `shouldBe` True

    it "does not list opaque foreigns" do
      Set.member (qname "Data.Ord" "ordArrayImpl") allowlist `shouldBe` False
      Set.member (qname "Data.Semiring" "numAdd") allowlist `shouldBe` False

qname ∷ Text → Text → QName
qname m n = QName (moduleNameFromString m) (Name n)

{- | Parse a foreign-module source into a 'Source', failing the test with a
clear message if it does not parse or interpret.
-}
source ∷ Text → Source
source src =
  case parseChunk "<test>" src of
    Left err → error (toText (renderParseError err))
    Right statements →
      case interpretForeignModule "<test>" statements of
        Left err → error (show err)
        Right parsed → parsed
