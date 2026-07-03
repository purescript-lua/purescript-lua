module Language.PureScript.Backend.IR.DCE.Spec where

import Data.Map qualified as Map
import Data.Set qualified as Set
import Hedgehog (Gen, annotate, annotateShow, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.PureScript.Backend.IR.DCE (EntryPoint (..), eliminateDeadCode)
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( lintUniqueBinders
  , lintWellScoped
  )
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (Name)
  , QName (QName)
  , Qualified (Local)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Query (collectBoundNames)
import Language.PureScript.Backend.IR.SpecUtils
  ( applyPassToExpression
  , emptyUberModule
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , Exp
  , Grouping (..)
  , abstraction
  , application
  , countFreeRefs
  , exception
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  )
import Language.PureScript.Backend.IR.Uniquify (uniquifyNamesInExpr)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Hedgehog.Extended (hedgehog, prop, test)
import Text.Pretty.Simple (pShow)

spec ∷ Spec
spec = describe "IR Dead Code Elimination" do
  let singletonModule ∷ Gen UberModule
      singletonModule = do
        name ← Gen.name
        moduleName ← Gen.moduleName
        expr ← Gen.nonRecursiveExp
        pure
          emptyUberModule
            { uberModuleBindings = [Standalone (QName moduleName name, expr)]
            , uberModuleExports = [(name, refImported moduleName name)]
            }

  test "doesn't eliminate an exported entry point" do
    optimalModule ← forAll singletonModule
    optimalModule === eliminateDeadCode optimalModule

  test "eliminates unused non-exported binding" do
    expected@UberModule {uberModuleBindings} ← forAll singletonModule
    let unoptimized =
          expected
            { uberModuleBindings = topBinding_ "unused" : uberModuleBindings
            }
    annotate . toString $ pShow unoptimized
    eliminateDeadCode unoptimized === expected

  -- The unit-level twin of the 'dcePass' ensures-contract: on GUC input
  -- (which the pipeline guarantees via the uniquify entry pass), DCE
  -- must keep the invariants intact while dropping dead binders.
  prop 100 "preserves the GUC invariants" do
    e ← forAll Gen.scopedExp
    let uber =
          emptyUberModule
            { uberModuleExports = [(Name "main", uniquifyNamesInExpr e)]
            }
        optimized = eliminateDeadCode uber
    annotateShow optimized
    lintWellScoped optimized === []
    lintUniqueBinders optimized === []

  test "detects named parameter unused by an abs-bindings" do
    -- DCE requires GUC input, so establish it before wrapping in a λ
    -- (unbound references from 'Gen.exp' survive uniquify as-is; DCE
    -- treats them as free).
    body ← uniquifyNamesInExpr <$> forAll Gen.exp
    let freeNames = [name | Local name ← Map.keys (countFreeRefs body)]
        boundNames = collectBoundNames body
    -- The new λ-binder must uphold the GUC precondition itself: it may
    -- neither capture a free reference nor duplicate a bound name.
    name ←
      forAll $
        mfilter
          (\n → n `notElem` freeNames && n `Set.notMember` boundNames)
          Gen.name
    dceExpression (abstraction (paramNamed name) body)
      === abstraction paramUnused body

  it "doesn't eliminate named parameter used by an abs-bindings" $ hedgehog do
    name ← forAll Gen.name
    let f = abstraction (paramNamed name) (refLocal name)
    dceExpression f === f

  test "eliminates unused non-recursive let-bindings" do
    {-
        let unusedOuter = exception "unusedOuter"
            a = 0
            b = 0
         in let unusedInner = exception "unusedInner"
                c = b
             in c a

    should be transformed to:

        let a = 0
            b = 0
         in let c = b
             in c a
    -}
    [a, b, c] ← forAll $ toList <$> Gen.set (Range.singleton 3) Gen.name
    bindA ← Standalone . (noAnn,a,) <$> forAll Gen.literalNonRecursiveExp
    bindB ← Standalone . (noAnn,b,) <$> forAll Gen.literalNonRecursiveExp
    let bindC = Standalone (noAnn, c, refLocal b)
        expr =
          lets
            (binding_ "unusedOuter" :| [bindA, bindB])
            ( lets
                (bindC :| [binding_ "unusedInner"])
                (application (refLocal c) (refLocal a))
            )
        expected =
          lets
            (bindA :| [bindB])
            ( lets
                (pure bindC)
                (application (refLocal c) (refLocal a))
            )
    annotate . toString $ pShow expr
    expected === dceExpression expr

  test "eliminates unused recursive let-bindings" do
    {-
    let a = b
        b = a
     in c
    -}
    [a, b, c] ← forAll $ toList <$> Gen.set (Range.singleton 3) Gen.name
    let expr =
          lets
            ( RecursiveGroup
                ((noAnn, a, refLocal b) :| [(noAnn, b, refLocal a)])
                :| []
            )
            (refLocal c)
        expected = refLocal c
    annotate . toString $ pShow expr
    expected === dceExpression expr

  -- There is deliberately no test here for two same-named Let siblings:
  -- the uniquify entry pass makes that input unreachable for DCE.
  -- Sequential (let*) resolution is covered by Uniquify.Spec ("renames
  -- a shadowing Let binder, resolving RHS pre-binding").

  -- 'Rewritten Recurse' descends into the result's children without
  -- re-applying the rule to the result itself. When a Let whose bindings
  -- are all dead collapses to its body, and the body is itself a Let,
  -- that inner Let node must not escape dead-code elimination: its dead
  -- bindings would be kept while the parameters of lambdas inside them
  -- are blanked (their ids are unreachable), leaving unbound references.
  it "eliminates dead bindings of a Let a collapsing Let exposes" $ hedgehog do
    let x = Name "x"
        k = Name "k"
        a = Name "a"
        expr =
          lets
            (Standalone (noAnn, a, literalInt 1) :| [])
            ( lets
                ( Standalone
                    (noAnn, k, abstraction (paramNamed x) (refLocal x))
                    :| []
                )
                (literalInt 3)
            )
    dceExpression expr === literalInt 3

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

dceExpression ∷ HasCallStack ⇒ Exp → Exp
dceExpression = applyPassToExpression "dceExpression" eliminateDeadCode

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

mainModuleName ∷ ModuleName
mainModuleName = moduleNameFromString "Main"

mainEntryPoint ∷ EntryPoint
mainEntryPoint = EntryPoint mainModuleName [Name "main"]

binding_ ∷ Text → Grouping (Ann, Name, Exp)
binding_ n = Standalone (noAnn, Name n, exception n)

topBinding_ ∷ Text → Grouping (QName, Exp)
topBinding_ n = Standalone (QName mainModuleName (Name n), exception n)
