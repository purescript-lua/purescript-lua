{-# LANGUAGE QuasiQuotes #-}

module Language.PureScript.Backend.Lua.Parser.Spec where

import Data.List (isInfixOf)
import Data.String.Interpolate (__i)
import Data.Text qualified as Text
import Hedgehog (annotate, failure, forAll, (===))
import Language.PureScript.Backend.Lua.Gen qualified as Gen
import Language.PureScript.Backend.Lua.Name qualified as Lua
import Language.PureScript.Backend.Lua.Parser
  ( ParseError
  , parseChunk
  , parseExpression
  , renderParseError
  )
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types (ParamF (..))
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Prettyprinter
  ( LayoutOptions (..)
  , PageWidth (..)
  , defaultLayoutOptions
  , layoutPretty
  , vsep
  )
import Prettyprinter.Render.Text (renderStrict)
import Test.Hspec
  ( Expectation
  , Spec
  , describe
  , expectationFailure
  , it
  , shouldSatisfy
  )
import Test.Hspec.Expectations.Pretty (shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)
import Prelude hiding (exp)

spec ∷ Spec
spec = do
  describe "expressions" do
    describe "literals" do
      it "nil, booleans" do
        "nil" `parsesTo` Lua.Nil
        "true" `parsesTo` Lua.Boolean True
        "false" `parsesTo` Lua.Boolean False

      it "decimal and hexadecimal integers" do
        "42" `parsesTo` Lua.Integer 42
        "0xFF" `parsesTo` Lua.Integer 255
        "0X10" `parsesTo` Lua.Integer 16
        "0x100000000" `parsesTo` Lua.Integer 4294967296

      it "floats: fraction, exponent, bare-dot forms" do
        "1.5" `parsesTo` Lua.Float 1.5
        ".5" `parsesTo` Lua.Float 0.5
        "1." `parsesTo` Lua.Float 1
        "1e2" `parsesTo` Lua.Float 100
        "1.5E-3" `parsesTo` Lua.Float 0.0015

      it "exponents: sign, capital E, bare-dot mantissa padding" do
        "1e+5" `parsesTo` Lua.Float 100000
        "1E5" `parsesTo` Lua.Float 100000
        ".5e3" `parsesTo` Lua.Float 500
        "1.e5" `parsesTo` Lua.Float 100000

      it "rejects malformed numerals" do
        expectExpParseError "0x"
        expectExpParseError "0xG"
        expectExpParseError "123abc"

      it "double-quoted strings keep escapes unexpanded" do
        "\"a\\255b\"" `parsesTo` Lua.String "a\\255b"
        "\"tab\\there\"" `parsesTo` Lua.String "tab\\there"

      it "escaped newlines normalize to the two-character escape" do
        "\"one\\\ntwo\"" `parsesTo` Lua.String "one\\ntwo"
        "\"one\\\r\ntwo\"" `parsesTo` Lua.String "one\\ntwo"

      it "'--' inside a string literal is not a comment" do
        "\"a--b\"" `parsesTo` Lua.String "a--b"

      it "rejects an unterminated string" do
        expectExpParseError "\"abc"

      it "rejects a raw newline inside a short string" do
        expectExpParseError "\"a\nb\""

      it "single-quoted strings convert to double-quoted form" do
        "'don\\'t say \"hi\"'" `parsesTo` Lua.String "don\\'t say \\\"hi\\\""

      it "long-bracket strings escape into double-quoted form" do
        "[[back\\slash \"quote\"]]"
          `parsesTo` Lua.String "back\\\\slash \\\"quote\\\""
        "[==[nested ]] here]==]" `parsesTo` Lua.String "nested ]] here"

      it "long-bracket strings drop the leading newline" do
        "[[\nfirst]]" `parsesTo` Lua.String "first"

      it "long-bracket strings escape interior raw newlines" do
        "[[a\nb]]" `parsesTo` Lua.String "a\\nb"
        "[[a\rb]]" `parsesTo` Lua.String "a\\rb"

      it "vararg" do
        "..." `parsesTo` Lua.Vararg

    describe "operators" do
      it "precedence: * binds tighter than +" do
        "1 + 2 * 3"
          `parsesTo` (Lua.Integer 1 `Lua.add` (Lua.Integer 2 `Lua.mul` Lua.Integer 3))

      it "left associativity of -" do
        "1 - 2 - 3"
          `parsesTo` ((Lua.Integer 1 `Lua.sub` Lua.Integer 2) `Lua.sub` Lua.Integer 3)

      it "right associativity of .. and ^" do
        "a .. b .. c"
          `parsesTo` (name' "a" `Lua.concat` (name' "b" `Lua.concat` name' "c"))
        "2 ^ 3 ^ 4"
          `parsesTo` ( Lua.Integer 2
                         `Lua.exponent` (Lua.Integer 3 `Lua.exponent` Lua.Integer 4)
                     )

      it "unary minus binds looser than ^" do
        -- -x^2 is -(x^2) in Lua
        "-x ^ 2"
          `parsesTo` Lua.negate (name' "x" `Lua.exponent` Lua.Integer 2)

      it "unary operator in the right operand of ^" do
        "2 ^ -3" `parsesTo` (Lua.Integer 2 `Lua.exponent` Lua.negate (Lua.Integer 3))

      it "not binds tighter than ==" do
        "not a == b" `parsesTo` (Lua.logicalNot (name' "a") `Lua.equalTo` name' "b")

      it "or/and precedence" do
        "a or b and c"
          `parsesTo` (name' "a" `Lua.or` (name' "b" `Lua.and` name' "c"))

      it "comparison and concat" do
        "#t .. x < y"
          `parsesTo` ( (Lua.hash (name' "t") `Lua.concat` name' "x")
                         `Lua.lessThan` name' "y"
                     )

    describe "prefix expressions" do
      it "field and index chains" do
        "a.b.c" `parsesTo` Lua.varField (Lua.varField (name' "a") (n "b")) (n "c")
        "a[1]" `parsesTo` Lua.varIndex (name' "a") (Lua.Integer 1)

      it "curried calls" do
        "f(1)(2)"
          `parsesTo` Lua.functionCall
            (Lua.functionCall (name' "f") [Lua.Integer 1])
            [Lua.Integer 2]

      it "method calls" do
        "s:sub(1, 2)"
          `parsesTo` Lua.methodCall (name' "s") (n "sub") [Lua.Integer 1, Lua.Integer 2]

      it "string- and table-argument call sugar" do
        [__i|f "x"|] `parsesTo` Lua.functionCall (name' "f") [Lua.String "x"]
        "f [[x]]" `parsesTo` Lua.functionCall (name' "f") [Lua.String "x"]
        "f {}" `parsesTo` Lua.functionCall (name' "f") [Lua.table []]

      it "parens around a call are semantic (multi-value adjustment)" do
        "(f(x))"
          `parsesTo` Lua.Paren
            (Lua.ann (Lua.functionCall (name' "f") [name' "x"]))
        "(...)" `parsesTo` Lua.Paren (Lua.ann Lua.Vararg)

      it "parens around single-valued expressions are grouping" do
        "(42)" `parsesTo` Lua.Integer 42
        "(a).b" `parsesTo` Lua.varField (name' "a") (n "b")

    describe "table constructors" do
      it "all three field forms and both separators" do
        [__i|{ [1] = "a", b = 2; 3 }|]
          `parsesTo` Lua.table
            [ Lua.tableRowKV (Lua.Integer 1) (Lua.String "a")
            , Lua.tableRowNV (n "b") (Lua.Integer 2)
            , Lua.tableRowV (Lua.Integer 3)
            ]

      it "trailing separator" do
        "{ 1, }" `parsesTo` Lua.table [Lua.tableRowV (Lua.Integer 1)]

    describe "functions" do
      it "vararg parameter" do
        "function(a, ...) return ... end"
          `parsesTo` Lua.Function
            [Lua.ann (ParamNamed (n "a")), Lua.ann ParamVararg]
            [Lua.ann (Lua.Return [Lua.ann Lua.Vararg])]

      it "rejects '...' before other parameters" do
        expectExpParseError "function(..., a) return 1 end"

  describe "statements" do
    it "multiple assignment stays simultaneous" do
      "a, b = b, a"
        `statParsesTo` Lua.Assign
          (Lua.ann (Lua.VarName (n "a")) :| [Lua.ann (Lua.VarName (n "b"))])
          (Lua.ann (name' "b") :| [Lua.ann (name' "a")])

    it "local declarations: single, multiple, uninitialized" do
      "local x = 1" `statParsesTo` Lua.local1 (n "x") (Lua.Integer 1)
      "local a, b = 1, x"
        `statParsesTo` Lua.Local
          (n "a" :| [n "b"])
          [Lua.ann (Lua.Integer 1), Lua.ann (name' "x")]
      "local y" `statParsesTo` Lua.local0 (n "y")

    it "local function is self-recursive" do
      "local function f() return f end"
        `statParsesTo` Lua.LocalFunction
          (n "f")
          []
          [Lua.ann (Lua.return (name' "f"))]

    it "function statements desugar to assignments" do
      "function M.f(x) return x end"
        `statParsesTo` Lua.assign
          (Lua.VarField (Lua.ann (name' "M")) (n "f"))
          (Lua.functionDef [ParamNamed (n "x")] [Lua.return (name' "x")])

    it "method definitions add the implicit self parameter" do
      "function M:m(x) return x end"
        `statParsesTo` Lua.assign
          (Lua.VarField (Lua.ann (name' "M")) (n "m"))
          ( Lua.functionDef
              [ParamNamed [Lua.name|self|], ParamNamed (n "x")]
              [Lua.return (name' "x")]
          )

    it "call statements" do
      "f(1)"
        `statParsesTo` Lua.CallStatement (Lua.ann (Lua.functionCall (name' "f") [Lua.Integer 1]))
      "s:close()"
        `statParsesTo` Lua.CallStatement (Lua.ann (Lua.methodCall (name' "s") (n "close") []))

    it "while, repeat, and do blocks" do
      "while x do break end"
        `statParsesTo` Lua.While (Lua.ann (name' "x")) [Lua.ann Lua.Break]
      "repeat f() until x"
        `statParsesTo` Lua.Repeat
          [Lua.ann (Lua.CallStatement (Lua.ann (Lua.functionCall (name' "f") [])))]
          (Lua.ann (name' "x"))
      "do local x = 1 end"
        `statParsesTo` Lua.Do [Lua.ann (Lua.local1 (n "x") (Lua.Integer 1))]

    it "numeric for with and without a step" do
      "for i = 1, 10 do f(i) end"
        `statParsesTo` Lua.ForNum
          (n "i")
          (Lua.ann (Lua.Integer 1))
          (Lua.ann (Lua.Integer 10))
          Nothing
          [ Lua.ann (Lua.CallStatement (Lua.ann (Lua.functionCall (name' "f") [name' "i"])))
          ]
      "for i = 10, 1, -1 do break end"
        `statParsesTo` Lua.ForNum
          (n "i")
          (Lua.ann (Lua.Integer 10))
          (Lua.ann (Lua.Integer 1))
          (Just (Lua.ann (Lua.negate (Lua.Integer 1))))
          [Lua.ann Lua.Break]

    it "generic for" do
      "for k, v in pairs(t) do break end"
        `statParsesTo` Lua.ForIn
          (n "k" :| [n "v"])
          (Lua.ann (Lua.functionCall (name' "pairs") [name' "t"]) :| [])
          [Lua.ann Lua.Break]

    it "bare and multi-value returns" do
      "return" `statParsesTo` Lua.Return []
      "return 1, 2"
        `statParsesTo` Lua.Return [Lua.ann (Lua.Integer 1), Lua.ann (Lua.Integer 2)]

    it "elseif chains parse into nested else-blocks" do
      [__i|
        if a then return 1
        elseif b then return 2
        else return 3 end
      |]
        `statParsesTo` Lua.ifThenElse
          (name' "a")
          [Lua.return (Lua.Integer 1)]
          [ Lua.ifThenElse
              (name' "b")
              [Lua.return (Lua.Integer 2)]
              [Lua.return (Lua.Integer 3)]
          ]

    it "rejects statements after a return" do
      expectChunkParseError "return 1 local x = 2"

    it "rejects an expression that is not a statement" do
      expectChunkParseError "x + 1"

    it "rejects an assignment whose left side is not a variable" do
      expectChunkParseError "f() = 1"

    it "rejects 'break' in the middle of a block" do
      expectChunkParseError "while true do break f() end"

    it "rejects a leading ';' (Lua 5.1 has no empty statement)" do
      expectChunkParseError ";"
      expectChunkParseError "; local x = 1"

    it "accepts ';' after every statement" do
      case parseChunk "<spec>" "local a = 1; local b = 2;" of
        Left err → expectationFailure (renderParseError err)
        Right stats →
          stats
            `shouldBe` [ Lua.ann (Lua.local1 (n "a") (Lua.Integer 1))
                       , Lua.ann (Lua.local1 (n "b") (Lua.Integer 2))
                       ]

    it "'repeat' whose body closes with a return" do
      "repeat return until x"
        `statParsesTo` Lua.Repeat
          [Lua.ann (Lua.Return [])]
          (Lua.ann (name' "x"))

    it "keyword-prefixed identifiers parse as identifiers" do
      "dofile(x)"
        `statParsesTo` Lua.CallStatement
          (Lua.ann (Lua.functionCall (name' "dofile") [name' "x"]))
      "local doit = 1" `statParsesTo` Lua.local1 (n "doit") (Lua.Integer 1)
      "returnValue()"
        `statParsesTo` Lua.CallStatement
          (Lua.ann (Lua.functionCall (name' "returnValue") []))

  describe "reference-parser conformance" do
    describe "ambiguous call syntax (function call x new statement)" do
      it "a call with '(' on the same line is a call" do
        "f(g)"
          `statParsesTo` Lua.CallStatement
            (Lua.ann (Lua.functionCall (name' "f") [name' "g"]))

      it "an inline block comment before '(' stays a call" do
        "f --[[c]] (g)"
          `statParsesTo` Lua.CallStatement
            ( Lua.ann
                ( Lua.FunctionCall
                    (Lua.ann (name' "f"))
                    [(["--[[c]]"], name' "g")]
                )
            )

      it "a line break before '(' is rejected as the reference rejects it" do
        expectChunkParseErrorWith "f\n(g)" "ambiguous syntax"
        expectChunkParseErrorWith "local x = f\n(g).y = 1" "ambiguous syntax"

      it "a line comment before '(' implies a line break: rejected" do
        expectChunkParseErrorWith "f --c\n(g)" "ambiguous syntax"

      it "a method call's argument list obeys the same rule" do
        expectChunkParseErrorWith "obj:m\n(x)" "ambiguous syntax"

      it "';' terminating the previous statement disambiguates" do
        case parseChunk "<spec>" "local a = f;\n(g).x = 1" of
          Left err → expectationFailure (renderParseError err)
          Right stats →
            stats
              `shouldBe` [ Lua.ann (Lua.local1 (n "a") (name' "f"))
                         , Lua.ann
                             ( Lua.Assign
                                 ( one
                                     ( Lua.ann
                                         ( Lua.VarField
                                             (Lua.ann (name' "g"))
                                             (n "x")
                                         )
                                     )
                                 )
                                 (one (Lua.ann (Lua.Integer 1)))
                             )
                         ]

      it "string and table arguments stay legal across a line break" do
        "f\n\"s\""
          `statParsesTo` Lua.CallStatement
            (Lua.ann (Lua.functionCall (name' "f") [Lua.String "s"]))
        "f\n{}"
          `statParsesTo` Lua.CallStatement
            (Lua.ann (Lua.functionCall (name' "f") [Lua.table []]))

    describe "vararg scope" do
      it "'...' at the top level is legal (the main chunk is vararg)" do
        "return ..." `statParsesTo` Lua.Return [Lua.ann Lua.Vararg]

      it "'...' inside a non-vararg function is rejected" do
        expectExpParseErrorWith
          "function() return ... end"
          "outside a vararg function"

      it "a nested non-vararg function shadows the enclosing vararg scope" do
        expectExpParseErrorWith
          "function(a, ...) return function() return ... end end"
          "outside a vararg function"

      it "leaving a nested vararg function restores the enclosing scope" do
        expectExpParseErrorWith
          "function() local g = function(...) return ... end return ... end"
          "outside a vararg function"

    describe "nesting depth cap" do
      it "parses 100 nested parentheses" do
        let src =
              Text.replicate 100 "(" <> "x" <> Text.replicate 100 ")"
        case parseExpression src of
          Left err → expectationFailure (renderParseError err)
          Right e → e `shouldBe` Lua.ann (name' "x")

      it "fails on 600 nested parentheses with a nesting error" do
        let src =
              Text.replicate 600 "(" <> "x" <> Text.replicate 600 ")"
        expectExpParseErrorWith src "nesting too deep"

      it "parses 50k call suffixes without exhausting the stack" do
        let src = "f" <> Text.replicate 50000 "()"
        parseExpression src `shouldSatisfy` isRight

      it "parses 50k field suffixes without exhausting the stack" do
        let src = "a" <> Text.replicate 50000 ".b"
        parseExpression src `shouldSatisfy` isRight

    describe "reserved words" do
      it "rejects 'goto' as an identifier (kept loadable on LuaJIT/5.2+)" do
        expectChunkParseErrorWith "local goto = 1" "goto"

  describe "comments" do
    it "attach to the following statement" do
      case parseChunk "<spec>" "-- doc\n-- more\nlocal x = 1" of
        Left err → expectationFailure (renderParseError err)
        Right stats →
          stats
            `shouldBe` [(["-- doc", "-- more"], Lua.local1 (n "x") (Lua.Integer 1))]

    it "block comments are preserved verbatim" do
      case parseChunk "<spec>" "--[[ block\ncomment ]]\nreturn 1" of
        Left err → expectationFailure (renderParseError err)
        Right stats →
          stats
            `shouldBe` [(["--[[ block\ncomment ]]"], Lua.return (Lua.Integer 1))]

    it "levelled long-bracket comments are preserved verbatim" do
      case parseChunk "<spec>" "--[==[ x ]==]\nreturn 1" of
        Left err → expectationFailure (renderParseError err)
        Right stats →
          stats `shouldBe` [(["--[==[ x ]==]"], Lua.return (Lua.Integer 1))]

    it "'--[' that does not open a long bracket is a line comment" do
      case parseChunk "<spec>" "--[ not long\nreturn 1" of
        Left err → expectationFailure (renderParseError err)
        Right stats →
          stats `shouldBe` [(["--[ not long"], Lua.return (Lua.Integer 1))]

    it "a comment at end of input (without a newline) is dropped" do
      "return 1 -- trailing" `statParsesTo` Lua.return (Lua.Integer 1)

    it "a comment before 'elseif' blocks resugaring, both ways" do
      -- Parses into the nested else-of-if shape with the comment attached;
      -- the printer then has to emit `else if … end end` (an `elseif` would
      -- lose the comment's place), and the reparse agrees exactly.
      let source =
            "if a then return 1\n-- why\nelseif b then return 2\nelse return 3 end"
      case parseChunk "<spec>" source of
        Left err → expectationFailure (renderParseError err)
        Right stats →
          stats
            `shouldBe` [ Lua.ann
                           ( Lua.IfThenElse
                               (Lua.ann (name' "a"))
                               [Lua.ann (Lua.return (Lua.Integer 1))]
                               [
                                 ( ["-- why"]
                                 , Lua.IfThenElse
                                     (Lua.ann (name' "b"))
                                     [Lua.ann (Lua.return (Lua.Integer 2))]
                                     [Lua.ann (Lua.return (Lua.Integer 3))]
                                 )
                               ]
                           )
                       ]
      roundTrips source

  describe "print/reparse round trip" do
    for_ roundTripCorpus \(title, source) →
      it title (roundTrips source)

    prop 500 "parse . print ≡ id for generated chunks, at every page width" do
      stats ← forAll Gen.block
      let doc = vsep (Printer.printStatements stats)
      for_ pageWidths \(label, options) → do
        let printed = renderStrict (layoutPretty options doc)
        annotate label
        annotate (toString printed)
        case parseChunk "<generated>" printed of
          Left err → do
            annotate (renderParseError err)
            failure
          Right parsed → parsed === stats

{- | The four layouts a chunk must survive: the one-column layout is the
main stress for @;@ insertion and hardline comments, 'Unbounded' for
everything the grouping logic can put on one line.
-}
pageWidths ∷ [(String, LayoutOptions)]
pageWidths =
  [ ("page width 1", LayoutOptions (AvailablePerLine 1 1.0))
  , ("page width 40", LayoutOptions (AvailablePerLine 40 1.0))
  , ("page width 80", defaultLayoutOptions)
  , ("page width unbounded", LayoutOptions Unbounded)
  ]

--------------------------------------------------------------------------------
-- Round-trip corpus -----------------------------------------------------------

{- | Parse, print with the real printer, reparse: the two parses must agree
exactly (including comment placement).
-}
roundTrips ∷ Text → Expectation
roundTrips source = case parseChunk "<original>" source of
  Left err → expectationFailure (renderParseError err)
  Right stats → do
    let printed =
          renderStrict . layoutPretty defaultLayoutOptions $
            vsep (Printer.printStatements stats)
    case parseChunk "<reprinted>" printed of
      Left err →
        expectationFailure $
          "Printed output failed to reparse:\n"
            <> toString printed
            <> "\n"
            <> renderParseError err
      Right stats' → stats' `shouldBe` stats

roundTripCorpus ∷ [(String, Text)]
roundTripCorpus =
  [
    ( "Data.Int-style header (methods, multi-locals, hex, repeat)"
    , [__i|
        -- Shared helpers.
        local function toInt32(m)
          m = math.modf(m)
          m = m % 0x100000000
          if m >= 0x80000000 then m = m - 0x100000000 end
          return m
        end
        local function digitValue(c)
          local b = c:byte()
          if b >= 48 and b <= 57 then return b - 48 end
          return nil
        end
        local sign, body = 1, s
        sign, body = -1, s:sub(2)
        repeat
          body = body .. "x"
        until \#body > 3 or digitValue(body)
        return { toInt32 = toInt32 }
      |]
    )
  ,
    ( "Array-style code (while, statement calls, generic for)"
    , [__i|
        local function listToArray(list)
          local arr = {}
          local i = 1
          local xs = list
          while xs.tag == "Cons" do
            arr[i] = xs.head
            i = i + 1
            xs = xs.tail
          end
          table.insert(arr, 1, 0)
          for k, v in pairs(arr) do
            print(k, v)
          end
          return arr
        end
        return { listToArray = listToArray }
      |]
    )
  ,
    ( "runtime-lazy fixture shape (nested closures, if/else)"
    , [__i|
        local function runtime_lazy(name)
          return function(init)
            local state = 0
            local val = nil
            return function()
              if state == 2 then
                return val
              else
                if state == 1 then
                  return error(name .. " loop")
                else
                  state = 1
                  val = init()
                  state = 2
                  return val
                end
              end
            end
          end
        end
        return { runtime_lazy = runtime_lazy }
      |]
    )
  ,
    ( "elseif ladder, numeric for, varargs, multi-value return"
    , [__i|
        local function classify(x, ...)
          if x < 0 then
            return "neg"
          elseif x == 0 then
            return "zero"
          elseif x < 10 then
            return "small"
          else
            return "big", select("\#", ...)
          end
        end
        local function sum(n)
          local acc = 0
          for i = 1, n, 2 do
            acc = acc + i
          end
          do
            acc = toInt32(acc)
          end
          return acc
        end
        return { classify = classify, sum = sum }
      |]
    )
  ,
    ( "comments in bodies and above exports"
    , [__i|
        -- header comment
        local unit = {}
        return {
          -- the unit value
          unit = unit,
          compare = function(a)
            -- inner comment
            return function(b)
              if a < b then return LT end
              return GT
            end
          end,
        }
      |]
    )
  ]

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

n ∷ Text → Lua.Name
n = Lua.unsafeName

name' ∷ Text → Lua.Exp
name' = Lua.varName . n

parsesTo ∷ HasCallStack ⇒ Text → Lua.Exp → Expectation
parsesTo source expected =
  case parseExpression source of
    Left err → expectationFailure (renderParseError err)
    Right e → e `shouldBe` Lua.ann expected

statParsesTo ∷ HasCallStack ⇒ Text → Lua.Statement → Expectation
statParsesTo source expected =
  case parseChunk "<spec>" source of
    Left err → expectationFailure (renderParseError err)
    Right stats → stats `shouldBe` [Lua.ann expected]

expectExpParseError ∷ HasCallStack ⇒ Text → Expectation
expectExpParseError source =
  case parseExpression source of
    Left _ → pass
    Right e → expectationFailure ("Expected a parse error, got: " <> show e)

expectChunkParseError ∷ HasCallStack ⇒ Text → Expectation
expectChunkParseError source =
  case parseChunk "<spec>" source of
    Left _ → pass
    Right e → expectationFailure ("Expected a parse error, got: " <> show e)

-- | Expect a parse error whose rendering mentions the given fragment.
expectExpParseErrorWith ∷ HasCallStack ⇒ Text → String → Expectation
expectExpParseErrorWith source fragment =
  expectErrorWith fragment (show <$> parseExpression source)

expectChunkParseErrorWith ∷ HasCallStack ⇒ Text → String → Expectation
expectChunkParseErrorWith source fragment =
  expectErrorWith fragment (show <$> parseChunk "<spec>" source)

expectErrorWith
  ∷ HasCallStack ⇒ String → Either ParseError String → Expectation
expectErrorWith fragment = \case
  Left err → do
    let message = renderParseError err
    unless (fragment `isInfixOf` message) . expectationFailure $
      "Expected an error mentioning "
        <> show fragment
        <> ", got:\n"
        <> message
  Right parsed →
    expectationFailure ("Expected a parse error, got: " <> parsed)
