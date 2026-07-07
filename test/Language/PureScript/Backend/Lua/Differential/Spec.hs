{- | Differential tests against the reference Lua implementation.

The @parse . print ≡ id@ round trip certifies the parser and the printer
against each other, so a /matched/ pair of defects — the parser misreading a
construct exactly the way the printer misprints it — is invisible to it.
The two properties here bring in an arbiter that cannot share such a bug:

  * @luac -p@ must accept everything the printer emits (syntax);
  * evaluating an expression printed normally and printed with parens around
    every node must agree inside @lua@ (semantics: the precedence\/
    associativity tables versus the interpreter, not versus themselves).
-}
module Language.PureScript.Backend.Lua.Differential.Spec where

import Data.Text qualified as Text
import Hedgehog (annotate, evalIO, forAll, (===))
import Language.PureScript.Backend.Lua.Gen qualified as Gen
import Language.PureScript.Backend.Lua.Parser qualified as Parser
import Language.PureScript.Backend.Lua.Parser.Spec (roundTripCorpus)
import Language.PureScript.Backend.Lua.Printer qualified as Printer
import Language.PureScript.Backend.Lua.Types (pattern Ann)
import Language.PureScript.Backend.Lua.Types qualified as Lua
import Prettyprinter (defaultLayoutOptions, layoutPretty, vsep)
import Prettyprinter.Render.Text (renderStrict)
import System.Process.Typed (ExitCode (..))
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe)
import Test.Hspec.Extra (annotatingWith)
import Test.Hspec.Hedgehog.Extended (prop)
import Test.Lua (luacParse, runLuaFile)
import Prelude hiding (exp)

spec ∷ Spec
spec = describe "differential against the reference Lua implementation" do
  describe "luac accepts everything the printer emits" do
    prop 100 "generated chunks" do
      stats ← forAll Gen.block
      let printed = renderBlock stats
      annotate (toString printed)
      (code, out) ← evalIO (luacParse printed)
      annotate (toString out)
      code === ExitSuccess

    for_ roundTripCorpus \(title, source) →
      it (title <> ": source and printed form") do
        (sourceCode, sourceOut) ← luacParse source
        sourceCode `shouldBe` ExitSuccess `annotatingWith` toString sourceOut
        case Parser.parseChunk "<corpus>" source of
          Left err → expectationFailure (Parser.renderParseError err)
          Right stats → do
            (printedCode, printedOut) ← luacParse (renderBlock stats)
            printedCode
              `shouldBe` ExitSuccess
                `annotatingWith` toString printedOut

  prop
    100
    "the printer's precedence/associativity agrees with the interpreter"
    do
      e ← forAll Gen.evaluableExp
      let script =
            Text.unlines
              [ "local a = " <> renderExp e
              , "local b = " <> fullParens e
              , -- Compare inside Lua (bit-for-bit for numbers, no output
                -- formatting involved); `a ~= a and b ~= b` admits NaN.
                "os.exit(((a == b) or (a ~= a and b ~= b)) and 0 or 1)"
              ]
      annotate (toString script)
      (code, out) ← evalIO (runLuaFile script)
      annotate (toString out)
      code === ExitSuccess

--------------------------------------------------------------------------------
-- Rendering -------------------------------------------------------------------

renderBlock ∷ [Lua.Annotated Lua.Comments Lua.StatementF] → Text
renderBlock =
  renderStrict
    . layoutPretty defaultLayoutOptions
    . vsep
    . Printer.printStatements

renderExp ∷ Lua.Exp → Text
renderExp = renderStrict . layoutPretty defaultLayoutOptions . Printer.printedExp

{- | Render the differential subset ('Gen.evaluableExp') with parentheses
around every node: a rendering whose evaluation order is dictated by the AST
alone, independent of the printer's precedence\/associativity tables.
-}
fullParens ∷ HasCallStack ⇒ Lua.Exp → Text
fullParens = \case
  e@(Lua.Integer _) → atom e
  e@(Lua.Float _) → atom e
  e@(Lua.Boolean _) → atom e
  e@(Lua.String _) → atom e
  Lua.UnOp op (Ann a) →
    parenthesized (Lua.sym op <> " " <> fullParens a)
  Lua.BinOp op (Ann l) (Ann r) →
    parenthesized (fullParens l <> " " <> Lua.sym op <> " " <> fullParens r)
  other → error ("outside the differential subset: " <> show other)
 where
  -- Literals reuse the printer's rendering (a formatting difference would
  -- compare different values); grouping parens around them are value-neutral.
  atom ∷ Lua.Exp → Text
  atom = parenthesized . renderExp
  parenthesized ∷ Text → Text
  parenthesized t = "(" <> t <> ")"
