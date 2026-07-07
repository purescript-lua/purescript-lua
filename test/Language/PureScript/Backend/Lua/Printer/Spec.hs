{-# LANGUAGE QuasiQuotes #-}
{-# OPTIONS_GHC -Wno-missing-local-signatures #-}

module Language.PureScript.Backend.Lua.Printer.Spec where

import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Parser qualified as Parser
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types (ParamF (..))
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Prettyprinter (Doc, defaultLayoutOptions, layoutPretty, vsep)
import Prettyprinter.Render.Text (renderStrict)
import Test.Hspec
  ( Expectation
  , Spec
  , describe
  , expectationFailure
  , it
  , shouldBe
  )

spec ∷ Spec
spec = do
  it "Name" do
    (rendered . Printer.printName) [Lua.name|foo|] `shouldBe` "foo"

  it "VarName" do
    renderedExpression (Lua.varName [Lua.name|foo|]) `shouldBe` "foo"

  describe "VarField" do
    it "var.field" do
      let e = Lua.varName [Lua.name|expr|]
          f = [Lua.name|foo|]
      renderedExpression (Lua.varField e f) `shouldBe` "expr.foo"

    it "({field = 1}).field" do
      let e = Lua.table [Lua.tableRowNV f (Lua.Integer 1)]
          f = [Lua.name|foo|]
      renderedExpression (Lua.varField e f) `shouldBe` "({ foo = 1 }).foo"

    it "Assignment" do
      let s = Lua.assign (Lua.VarName [Lua.name|foo|]) (Lua.Boolean True)
      renderedStatement s `shouldBe` "foo = true"

  describe "VarIndex" do
    it "var[index]" do
      let e = Lua.varName [Lua.name|expr|]
      renderedExpression (Lua.varIndex e (Lua.String "foo"))
        `shouldBe` "expr[\"foo\"]"

    -- A table constructor must be parenthesised before bracket indexing:
    -- `{ ["foo"] = 1 }["foo"]` is a Lua syntax error, `({ … })["foo"]` is not.
    it "({[\"foo\"] = 1})[\"foo\"]" do
      let e = Lua.table [Lua.tableRowKV (Lua.String "foo") (Lua.Integer 1)]
      renderedExpression (Lua.varIndex e (Lua.String "foo"))
        `shouldBe` "({ [\"foo\"] = 1 })[\"foo\"]"

  describe "Local declaration" do
    it "without a value" do
      let s = Lua.local0 [Lua.name|foo|]
      renderedStatement s `shouldBe` "local foo"

    it "with value" do
      let s = Lua.local [Lua.name|foo|] (Just (Lua.Boolean True))
      renderedStatement s `shouldBe` "local foo = true"

  describe "If Then Else" do
    it "if / then" do
      let p = Lua.Boolean True
      let t = pure $ Lua.return $ Lua.Integer 1
      let s = Lua.ifThenElse p t []
      renderedStatement s `shouldBe` "if true then return 1 end"
    it "if / then / else" do
      let p = Lua.Boolean True
      let t = pure $ Lua.return $ Lua.Integer 1
      let e = pure $ Lua.return $ Lua.Integer 0
      let s = Lua.ifThenElse p t e
      renderedStatement s `shouldBe` "if true then return 1 else return 0 end"

  describe "Return" do
    it "statement" do
      let s = Lua.return $ Lua.Boolean True
      renderedStatement s `shouldBe` "return true"

  describe "Table" do
    it "empty" do
      renderedExpression (Lua.table []) `shouldBe` "{}"

    it "small table constructor in one line" do
      let e =
            Lua.table
              [ Lua.tableRowKV (Lua.Integer 42) (Lua.Boolean True)
              , Lua.tableRowNV [Lua.name|foo|] (Lua.String "ok")
              ]
      renderedExpression e `shouldBe` "{ [42] = true, foo = \"ok\" }"

    it "large table constructor on muliple lines" do
      let e =
            Lua.table
              [ Lua.tableRowKV (Lua.Integer 42) (Lua.Boolean True)
              , Lua.tableRowNV [Lua.name|foo|] (Lua.String "bar")
              , Lua.tableRowNV [Lua.name|loooooooooooong1|] (Lua.String "value")
              , Lua.tableRowNV [Lua.name|loooooooooooong2|] (Lua.String "value")
              ]
      renderedExpression e
        `shouldBe` multiline
          [ "{"
          , "  [42] = true,"
          , "  foo = \"bar\","
          , "  loooooooooooong1 = \"value\","
          , "  loooooooooooong2 = \"value\""
          , "}"
          ]

  describe "function" do
    it "one-liner" do
      let params = ParamNamed <$> [[Lua.name|a|], [Lua.name|b|]]
      let result = Lua.Integer 1
      let stats = [Lua.assign (Lua.VarName [Lua.name|x|]) Lua.Nil]
      let expr = Lua.functionDef params (stats <> [Lua.return result])
      renderedExpression expr `shouldBe` "function(a, b) x = nil return 1 end"

    it "multi-liner" do
      let params = ParamNamed <$> [[Lua.name|aaa|], [Lua.name|bbb|]]
      let result =
            Lua.varName
              [Lua.name|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|]
      let stats = [Lua.assign (Lua.VarName [Lua.name|x|]) Lua.Nil]
      let expr = Lua.functionDef params (stats <> [Lua.return result])
      renderedExpression expr
        `shouldBe` multiline
          [ "function(aaa, bbb)"
          , "  x = nil"
          , "  return aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
          , "end"
          ]
    it "function application" do
      let expr =
            Lua.functionCall
              ( Lua.functionDef
                  [ParamNamed [Lua.name|a|], ParamNamed [Lua.name|b|]]
                  [Lua.return (Lua.varName [Lua.name|a|])]
              )
              [Lua.Integer 1, Lua.Integer 2]
      renderedExpression expr
        `shouldBe` "(function(a, b) return a end)(1, 2)"

  describe "expression" do
    describe "unary" do
      it "hash" do
        renderedExpression (Lua.hash (Lua.varName [Lua.name|foo|]))
          `shouldBe` "#(foo)"

      it "negate" do
        renderedExpression (Lua.negate (Lua.varName [Lua.name|foo|]))
          `shouldBe` "-(foo)"

      it "logicalNot" do
        renderedExpression (Lua.logicalNot (Lua.varName [Lua.name|foo|]))
          `shouldBe` "not(foo)"

      it "bitwiseNot" do
        renderedExpression (Lua.bitwiseNot (Lua.varName [Lua.name|foo|]))
          `shouldBe` "~(foo)"

    describe "binary" do
      it "Op with lower precedence is braced" do
        renderedExpression
          ((Lua.Integer 2 `Lua.add` Lua.Integer 3) `Lua.mul` Lua.Integer 4)
          `shouldBe` "(2 + 3) * 4"

      it "Op with higher precedence is not braced" do
        renderedExpression
          (Lua.Integer 2 `Lua.add` (Lua.Integer 3 `Lua.mul` Lua.Integer 4))
          `shouldBe` "2 + 3 * 4"

      -- https://github.com/purescript-lua/purescript-lua/issues/164
      describe "same-precedence associativity" do
        it "left-nested left-associative op needs no parens: (1 - 2) - 3" do
          renderedExpression
            ((Lua.Integer 1 `Lua.sub` Lua.Integer 2) `Lua.sub` Lua.Integer 3)
            `shouldBe` "1 - 2 - 3"

        it "right-nested left-associative op needs parens: 1 - (2 - 3)" do
          renderedExpression
            (Lua.Integer 1 `Lua.sub` (Lua.Integer 2 `Lua.sub` Lua.Integer 3))
            `shouldBe` "1 - (2 - 3)"

        it "right-nested same-level op needs parens: 1 - (2 + 3)" do
          renderedExpression
            (Lua.Integer 1 `Lua.sub` (Lua.Integer 2 `Lua.add` Lua.Integer 3))
            `shouldBe` "1 - (2 + 3)"

        it "right-nested same-level op needs parens: 1 / (2 * 3)" do
          renderedExpression
            ( Lua.Integer 1
                `Lua.floatDiv` (Lua.Integer 2 `Lua.mul` Lua.Integer 3)
            )
            `shouldBe` "1 / (2 * 3)"

        it "comparisons parse left, so nesting on the right needs parens" do
          renderedExpression
            ( Lua.Integer 1
                `Lua.equalTo` (Lua.Integer 2 `Lua.equalTo` Lua.Integer 3)
            )
            `shouldBe` "1 == (2 == 3)"

        it "right-nested right-associative op needs no parens: 1 ^ (2 ^ 3)" do
          renderedExpression
            ( Lua.Integer 1
                `Lua.exponent` (Lua.Integer 2 `Lua.exponent` Lua.Integer 3)
            )
            `shouldBe` "1 ^ 2 ^ 3"

        it "left-nested right-associative op needs parens: (1 ^ 2) ^ 3" do
          renderedExpression
            ( (Lua.Integer 1 `Lua.exponent` Lua.Integer 2)
                `Lua.exponent` Lua.Integer 3
            )
            `shouldBe` "(1 ^ 2) ^ 3"

        it "left-nested concat needs parens to preserve the AST shape" do
          renderedExpression
            ( (Lua.String "a" `Lua.concat` Lua.String "b")
                `Lua.concat` Lua.String "c"
            )
            `shouldBe` "(\"a\" .. \"b\") .. \"c\""

  describe "prefix position" do
    -- https://github.com/purescript-lua/purescript-lua/issues/164
    it "a string literal needs parens before a field access" do
      renderedExpression (Lua.varField (Lua.String "s") [Lua.name|foo|])
        `shouldBe` "(\"s\").foo"

    it "a table constructor needs parens before a call" do
      let callee = Lua.table [Lua.tableRowNV [Lua.name|foo|] (Lua.Integer 1)]
      renderedExpression (Lua.functionCall callee [])
        `shouldBe` "({ foo = 1 })()"

  describe "statement separator" do
    -- Without the ';', `local a = f` and the next line's `(` would fuse
    -- into the call `f(nil)` — Lua 5.1 rejects that as "ambiguous syntax".
    it "';' terminates a statement when the next one starts with '('" do
      let stats =
            [ Lua.ann
                (Lua.local1 [Lua.name|a|] (Lua.varName [Lua.name|f|]))
            , Lua.ann
                ( Lua.Assign
                    ( one
                        ( Lua.ann
                            (Lua.VarField (Lua.ann Lua.Nil) [Lua.name|x|])
                        )
                    )
                    (one (Lua.ann (Lua.Integer 1)))
                )
            ]
      renderedStatements stats
        `shouldBe` multiline ["local a = f;", "(nil).x = 1"]
      reparsesToItself stats

    it "';' separates an IIFE from a preceding call statement" do
      let stats =
            [ Lua.ann . Lua.CallStatement . Lua.ann $
                Lua.functionCall (Lua.varName [Lua.name|f|]) []
            , Lua.ann . Lua.CallStatement . Lua.ann $
                Lua.functionCall (Lua.functionDef [] [Lua.Return []]) []
            ]
      renderedStatements stats
        `shouldBe` multiline ["f();", "(function() return end)()"]
      reparsesToItself stats

    it "no ';' when the next statement starts with a name" do
      let stats =
            [ Lua.ann . Lua.CallStatement . Lua.ann $
                Lua.functionCall (Lua.varName [Lua.name|f|]) []
            , Lua.ann . Lua.CallStatement . Lua.ann $
                Lua.functionCall (Lua.varName [Lua.name|g|]) []
            ]
      renderedStatements stats `shouldBe` multiline ["f()", "g()"]
      reparsesToItself stats

  describe "statements from parsed foreign code" do
    it "multiple assignment" do
      let s =
            Lua.Assign
              (Lua.ann (Lua.VarName [Lua.name|a|]) :| [Lua.ann (Lua.VarName [Lua.name|b|])])
              (Lua.ann (Lua.varName [Lua.name|b|]) :| [Lua.ann (Lua.varName [Lua.name|a|])])
      renderedStatement s `shouldBe` "a, b = b, a"

    it "multi-name local declaration" do
      let s =
            Lua.Local
              ([Lua.name|a|] :| [[Lua.name|b|]])
              [Lua.ann (Lua.Integer 1), Lua.ann (Lua.Integer 2)]
      renderedStatement s `shouldBe` "local a, b = 1, 2"

    it "local function" do
      let s =
            Lua.LocalFunction
              [Lua.name|go|]
              [Lua.ann (ParamNamed [Lua.name|n|])]
              [Lua.ann (Lua.return (Lua.varName [Lua.name|n|]))]
      renderedStatement s `shouldBe` "local function go(n) return n end"

    it "while / repeat / break" do
      renderedStatement
        (Lua.While (Lua.ann (Lua.Boolean True)) [Lua.ann Lua.Break])
        `shouldBe` "while true do break end"
      renderedStatement
        (Lua.Repeat [Lua.ann Lua.Break] (Lua.ann (Lua.Boolean True)))
        `shouldBe` "repeat break until true"

    it "numeric for renders its optional step" do
      let body = [Lua.ann Lua.Break]
      renderedStatement
        ( Lua.ForNum
            [Lua.name|i|]
            (Lua.ann (Lua.Integer 1))
            (Lua.ann (Lua.Integer 9))
            Nothing
            body
        )
        `shouldBe` "for i = 1, 9 do break end"
      renderedStatement
        ( Lua.ForNum
            [Lua.name|i|]
            (Lua.ann (Lua.Integer 9))
            (Lua.ann (Lua.Integer 1))
            (Just (Lua.ann (Lua.negate (Lua.Integer 1))))
            body
        )
        `shouldBe` "for i = 9, 1, -(1) do break end"

    it "generic for over pairs" do
      renderedStatement
        ( Lua.ForIn
            ([Lua.name|k|] :| [[Lua.name|v|]])
            ( Lua.ann
                (Lua.functionCall (Lua.varName [Lua.name|pairs|]) [Lua.varName [Lua.name|t|]])
                :| []
            )
            [Lua.ann Lua.Break]
        )
        `shouldBe` "for k, v in pairs(t) do break end"

    it "do-block and call statement" do
      renderedStatement
        ( Lua.Do
            [ Lua.ann . Lua.CallStatement . Lua.ann $
                Lua.functionCall (Lua.varName [Lua.name|f|]) []
            ]
        )
        `shouldBe` "do f() end"

    it "bare and multi-value return" do
      renderedStatement (Lua.Return []) `shouldBe` "return"
      renderedStatement
        (Lua.Return [Lua.ann (Lua.Integer 1), Lua.ann (Lua.Integer 2)])
        `shouldBe` "return 1, 2"

    it "an else-block holding a single if prints as elseif" do
      let s =
            Lua.ifThenElse
              (Lua.varName [Lua.name|a|])
              [Lua.return (Lua.Integer 1)]
              [ Lua.ifThenElse
                  (Lua.varName [Lua.name|b|])
                  [Lua.return (Lua.Integer 2)]
                  [Lua.return (Lua.Integer 3)]
              ]
      renderedStatement s
        `shouldBe` "if a then return 1 elseif b then return 2 else return 3 end"

  describe "expressions from parsed foreign code" do
    it "method call" do
      renderedExpression
        (Lua.methodCall (Lua.varName [Lua.name|s|]) [Lua.name|sub|] [Lua.Integer 1])
        `shouldBe` "s:sub(1)"

    it "vararg expression and parameter" do
      renderedExpression
        (Lua.Function [Lua.ann ParamVararg] [Lua.ann (Lua.return Lua.Vararg)])
        `shouldBe` "function(...) return ... end"

    it "multi-value adjustment parens are preserved" do
      renderedExpression
        (Lua.Paren (Lua.ann (Lua.functionCall (Lua.varName [Lua.name|f|]) [])))
        `shouldBe` "(f())"

    it "array-part table row" do
      renderedExpression (Lua.table [Lua.tableRowV (Lua.Integer 7)])
        `shouldBe` "{ 7 }"

  describe "comments" do
    it "print on their own lines before the annotated node" do
      let s =
            ( ["-- doc", "-- more"]
            , Lua.local1 [Lua.name|x|] (Lua.Integer 1)
            )
      rendered (Printer.printStatementA s)
        `shouldBe` multiline ["-- doc", "-- more", "local x = 1"]

    it "force a table constructor into vertical layout" do
      let e =
            Lua.TableCtor
              [ (["-- why"], Lua.tableRowNV [Lua.name|foo|] (Lua.Integer 1))
              ]
      renderedExpression e
        `shouldBe` multiline ["{", "  -- why", "  foo = 1", "}"]

  describe "Float" do
    -- https://github.com/purescript-lua/purescript-lua/issues/164
    it "NaN prints as a Lua-readable expression, not \"NaN\"" do
      renderedExpression (Lua.Float (0 / 0)) `shouldBe` "(0/0)"

    it "positive infinity prints as math.huge, not \"Infinity\"" do
      renderedExpression (Lua.Float (1 / 0)) `shouldBe` "math.huge"

    it "negative infinity prints as -math.huge, not \"-Infinity\"" do
      renderedExpression (Lua.Float (-(1 / 0))) `shouldBe` "-math.huge"

    it "negative infinity as the base of ^ still needs parens" do
      renderedExpression (Lua.Float (-(1 / 0)) `Lua.exponent` Lua.Integer 2)
        `shouldBe` "(-math.huge) ^ 2"

    it "negative literals carry unary precedence: parens under ^" do
      renderedExpression (Lua.Integer (-2) `Lua.exponent` Lua.Integer 2)
        `shouldBe` "(-2) ^ 2"
      renderedExpression (Lua.Float (-1.5) `Lua.exponent` Lua.Integer 2)
        `shouldBe` "(-1.5) ^ 2"

    it "negative literals need no parens under looser operators" do
      renderedExpression (Lua.Integer (-2) `Lua.add` Lua.Integer 1)
        `shouldBe` "-2 + 1"

--------------------------------------------------------------------------------
-- Utility functions -----------------------------------------------------------

multiline ∷ [Text] → Text
multiline = Text.concat . intersperse "\n"

renderedStatement ∷ Lua.Statement → Text
renderedStatement = rendered . Printer.printStatement

renderedStatements ∷ [Lua.Annotated Lua.Comments Lua.StatementF] → Text
renderedStatements = rendered . vsep . Printer.printStatements

-- | The printed form must parse back to exactly the same statements.
reparsesToItself
  ∷ HasCallStack ⇒ [Lua.Annotated Lua.Comments Lua.StatementF] → Expectation
reparsesToItself stats =
  case Parser.parseChunk "<printed>" (renderedStatements stats) of
    Left err → expectationFailure (Parser.renderParseError err)
    Right reparsed → reparsed `shouldBe` stats

renderedExpression ∷ Lua.Exp → Text
renderedExpression = rendered . Printer.printedExp

rendered ∷ Doc ann → Text
rendered = renderStrict . layoutPretty defaultLayoutOptions
