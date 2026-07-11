module Language.PureScript.Backend.Lua.ForeignLift.Spec where

import Language.PureScript.Backend.IR.Names (Name (..))
import Language.PureScript.Backend.IR.Types
  ( PrimOp (..)
  , abstraction
  , abstractionN
  , application
  , applicationN
  , eq
  , ifThenElse
  , noAnn
  , paramNamed
  , paramUnused
  , primBinOp
  , primNot
  , refLocal
  , pattern EffectRunArg
  )
import Language.PureScript.Backend.Lua.ForeignLift (liftExport)
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

    it "lifts a multi-parameter function literal to one n-ary AbsN (#227)" do
      -- A Lua function binds every parameter at one call, so the literal
      -- becomes a single n-ary 'AbsN' — nested unary 'Abs' would misapply
      -- when curried (Note [n-ary application]).
      liftExport
        (source "return { f = function(x, y) return x + y end }")
        (Name "f")
        `shouldBe` Just
          ( abstractionN (paramNamed (Name "x") :| [paramNamed (Name "y")]) $
              primBinOp PrimAdd (refLocal (Name "x")) (refLocal (Name "y"))
          )

  describe "lifts the *.Uncurried run wrappers (#198)" do
    it "lifts runFn3 to a saturated n-ary call" do
      -- The pure wrapper: `\fn a b c -> fn(a, b, c)`. The body is a single
      -- Lua call of every parameter at once, which lifts to the n-ary AppN
      -- node. Marked inline-always downstream, a saturated site beta-reduces
      -- to a direct `AppN impl [x, y, z]`.
      let src =
            "return { runFn3 = function(fn) return function(a) "
              <> "return function(b) return function(c) "
              <> "return fn(a, b, c) end end end end }"
          fn = Name "fn"
          a = Name "a"
          b = Name "b"
          c = Name "c"
      liftExport (source src) (Name "runFn3")
        `shouldBe` Just
          ( abstraction (paramNamed fn) $
              abstraction (paramNamed a) $
                abstraction (paramNamed b) $
                  abstraction (paramNamed c) $
                    applicationN
                      (refLocal fn)
                      (refLocal a :| [refLocal b, refLocal c])
          )

    it "lifts runSTFn2 to a thunk over an n-ary call" do
      -- The effectful wrapper: `\fn a b -> \() -> fn(a, b)`. The trailing
      -- `function()` thunk becomes a unary lambda with an unused parameter
      -- (Abs paramUnused) — the exact shape magic-do runs in statement
      -- position and codegen then sheds, so the thunk and its three
      -- closures fuse away.
      let src =
            "return { runSTFn2 = function(fn) return function(a) "
              <> "return function(b) return function() "
              <> "return fn(a, b) end end end end }"
          fn = Name "fn"
          a = Name "a"
          b = Name "b"
      liftExport (source src) (Name "runSTFn2")
        `shouldBe` Just
          ( abstraction (paramNamed fn) $
              abstraction (paramNamed a) $
                abstraction (paramNamed b) $
                  abstraction paramUnused $
                    applicationN (refLocal fn) (refLocal a :| [refLocal b])
          )

    it "lifts runEffectFn1 (single-argument n-ary call under a thunk)" do
      let src =
            "return { runEffectFn1 = function(fn) return function(a) "
              <> "return function() return fn(a) end end end }"
          fn = Name "fn"
          a = Name "a"
      liftExport (source src) (Name "runEffectFn1")
        `shouldBe` Just
          ( abstraction (paramNamed fn) $
              abstraction (paramNamed a) $
                abstraction paramUnused $
                  applicationN (refLocal fn) (refLocal a :| [])
          )

  describe "lifts the *.Uncurried mk wrappers (#227)" do
    it "lifts mkFn2 to an n-ary literal over a re-curried call" do
      -- `mkFn2 = \fn -> function(a, b) return fn(a)(b) end`: the inner
      -- multi-parameter literal becomes a single n-ary 'AbsN'; its body
      -- re-curries the wrapped function, so the call chain lifts as
      -- nested unary applications. Marked inline-always downstream, a
      -- `mkFn2 \a b -> …` definition beta-reduces to the two-parameter
      -- literal itself — zero closures per call.
      let src =
            "return { mkFn2 = function(fn) "
              <> "return function(a, b) return fn(a)(b) end end }"
          fn = Name "fn"
          a = Name "a"
          b = Name "b"
      liftExport (source src) (Name "mkFn2")
        `shouldBe` Just
          ( abstraction (paramNamed fn) $
              abstractionN (paramNamed a :| [paramNamed b]) $
                applicationN
                  (applicationN (refLocal fn) (refLocal a :| []))
                  (refLocal b :| [])
          )

    it "lifts mkEffectFn2 (effect run of the re-curried call)" do
      -- `mkEffectFn2 = \fn -> function(a, b) return fn(a)(b)() end`: the
      -- trailing nullary call runs the effect the wrapped function
      -- returns, and lifts as an application to the 'EffectRunArg'
      -- marker — the shape magic-do emits, erased to an empty argument
      -- list at code generation.
      let src =
            "return { mkEffectFn2 = function(fn) "
              <> "return function(a, b) return fn(a)(b)() end end }"
          fn = Name "fn"
          a = Name "a"
          b = Name "b"
      liftExport (source src) (Name "mkEffectFn2")
        `shouldBe` Just
          ( abstraction (paramNamed fn) $
              abstractionN (paramNamed a :| [paramNamed b]) $
                application
                  ( applicationN
                      (applicationN (refLocal fn) (refLocal a :| []))
                      (refLocal b :| [])
                  )
                  (EffectRunArg noAnn)
          )

    it "lifts mkSTFn1 (unary inner literal, the nullary-call half alone)" do
      -- The arity-1 wrappers keep a unary inner literal, so this
      -- exercises only the nullary-call half of #227: `fn(a)()` becomes
      -- the effect-run application under a plain unary 'Abs'.
      let src =
            "return { mkSTFn1 = function(fn) "
              <> "return function(a) return fn(a)() end end }"
          fn = Name "fn"
          a = Name "a"
      liftExport (source src) (Name "mkSTFn1")
        `shouldBe` Just
          ( abstraction (paramNamed fn) $
              abstraction (paramNamed a) $
                application
                  (applicationN (refLocal fn) (refLocal a :| []))
                  (EffectRunArg noAnn)
          )

    it "lifts a nullary call to an effect-run application" do
      -- `runFn0 = \fn -> fn()`. The zero-argument call lifts as an
      -- application to the 'EffectRunArg' marker. `runFn0`/`mkFn0`
      -- nonetheless stay off the allowlist by policy, not liftability:
      -- forcing a pure `Fn0` is not an effect run and must not be
      -- marked as one.
      liftExport
        (source "return { runFn0 = function(fn) return fn() end }")
        (Name "runFn0")
        `shouldBe` Just
          ( abstraction (paramNamed (Name "fn")) $
              application (refLocal (Name "fn")) (EffectRunArg noAnn)
          )

  describe "declines everything outside the subset" do
    it "declines a vararg function literal" do
      liftExport
        (source "return { f = function(a, ...) return a end }")
        (Name "f")
        `shouldSatisfy` isNothing

    it "declines duplicate parameter names" do
      -- Lua's `function(a, a)` binds the body's `a` to the *last*
      -- parameter; an 'AbsN' with two same-named parameters would
      -- silently miscompile that reference, so the literal declines.
      liftExport
        (source "return { f = function(a, a) return a end }")
        (Name "f")
        `shouldSatisfy` isNothing

    it "declines a literal-lambda call at a mismatched arity" do
      -- `local k = function(x) return x end; f = \a -> k(a, a)`: legal
      -- Lua (the surplus argument is dropped), but the header local
      -- inlines to a literal unary 'Abs', and applying it to two
      -- arguments would build an ill-formed 'AppN' (Note [n-ary
      -- application]) — so the export declines instead.
      let src =
            "local k = function(x) return x end\n"
              <> "return { f = function(a) return k(a, a) end }"
      liftExport (source src) (Name "f") `shouldSatisfy` isNothing

    it "declines an under-applied multi-parameter literal head" do
      -- The mirror image: `local k = function(a, b) return a end` now
      -- inlines to a two-parameter 'AbsN' (#227), and calling it with
      -- one argument would again build an ill-formed 'AppN' — Lua pads
      -- the missing parameter with nil, so the mismatch declines.
      let src =
            "local k = function(a, b) return a end\n"
              <> "return { f = function(x) return k(x) end }"
      liftExport (source src) (Name "f") `shouldSatisfy` isNothing

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
