{-# OPTIONS_GHC -Wno-missing-local-signatures #-}

module Language.PureScript.Backend.IR.Spec where

import Data.List.NonEmpty qualified as NE
import Data.Map.Strict qualified as Map
import Language.PureScript.Backend.IR
  ( Context (..)
  , RepM
  , collectDataDeclarations
  , mkCase
  , mkModule
  , runRepM
  )
import Data.List qualified as List
import Language.PureScript.Backend.IR.Inliner
  ( Annotation (Always, Arity, Never)
  )
import Language.PureScript.Backend.IR.Inliner qualified as Inliner
import Language.PureScript.Comments (Comment (LineComment))
import Language.PureScript.Backend.IR.Names
  ( CtorName (..)
  , Name (..)
  , PropName (..)
  , TyName (..)
  )
import Language.PureScript.Backend.IR.Types
import Language.PureScript.CoreFn qualified as Cfn
import Language.PureScript.Names qualified as PS
import Language.PureScript.PSString qualified as PS
import Test.Hspec
  ( Expectation
  , Spec
  , describe
  , expectationFailure
  , it
  , shouldBe
  , shouldSatisfy
  )

spec ∷ Spec
spec = describe "IR representation" do
  describe "module translation attaches inline directives" do
    it "annotates an application-rooted binding" do
      irModule ←
        translateModule
          ["@inline foo always"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnApp (cfnImportedRef "bar") (cfnInt 1))]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just Always)
    it "annotates a variable-rooted binding" do
      irModule ←
        translateModule
          ["@inline foo never"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just Never)

    it "annotates a binding with an arity directive" do
      irModule ←
        translateModule
          ["@inline foo arity=2"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just (Arity 2))

    it "an explicit default attaches no annotation" do
      irModule ←
        translateModule
          ["@inline foo default"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just Nothing

    it "attaches a field directive to a dictionary record field" do
      irModule ←
        translateModule
          ["@inline dict.method never"]
          [ Cfn.NonRec ann (PS.Ident "dict") $
              cfnObject [("method", cfnInt 1), ("other", cfnInt 2)]
          ]
      fieldAnn (Name "dict") (PropName "method") irModule
        `shouldBe` Just (Just Never)
      fieldAnn (Name "dict") (PropName "other") irModule
        `shouldBe` Just Nothing

    it "attaches an applied-field directive under a lambda" do
      irModule ←
        translateModule
          ["@inline mk...method always"]
          [ Cfn.NonRec ann (PS.Ident "mk") $
              Cfn.Abs ann (PS.Ident "x") $
                cfnObject [("method", cfnInt 1)]
          ]
      fieldAnn (Name "mk") (PropName "method") irModule
        `shouldBe` Just (Just Always)

    it "rejects a field directive on a lambda binding" do
      translate
        mempty
        ["@inline mk.method never"]
        [ Cfn.NonRec ann (PS.Ident "mk") $
            Cfn.Abs ann (PS.Ident "x") $
              cfnObject [("method", cfnInt 1)]
        ]
        []
        `shouldFailWith` "does not match the shape"

    it "rejects an accessor directive naming a missing field" do
      translate
        mempty
        ["@inline dict.ghost never"]
        [ Cfn.NonRec ann (PS.Ident "dict") $
            cfnObject [("method", cfnInt 1)]
        ]
        []
        `shouldFailWith` "does not match the shape"

    it "rejects a header directive naming a missing binding" do
      translate
        mempty
        ["@inline ghost always"]
        [Cfn.NonRec ann (PS.Ident "foo") (cfnInt 1)]
        []
        `shouldFailWith` "Unused annotations"

    it "silently ignores unmatched directives-file entries" do
      irModule ←
        translateModuleWith
          ( directivesFor
              [ ((Name "ghost", Nothing), Inliner.ModeAnnotation Always)
              ,
                ( (Name "foo", Just (Inliner.Field (PropName "nope")))
                , Inliner.ModeAnnotation Never
                )
              ]
          )
          []
          [Cfn.NonRec ann (PS.Ident "foo") (cfnInt 1)]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just Nothing

    it "applies a directives-file entry to its binding" do
      irModule ←
        translateModuleWith
          (directivesFor [((Name "foo", Nothing), Inliner.ModeAnnotation Never)])
          []
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just Never)

    it "a local header directive beats the directives file" do
      irModule ←
        translateModuleWith
          (directivesFor [((Name "foo", Nothing), Inliner.ModeAnnotation Never)])
          ["@inline foo always"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just Always)

    it "the directives file beats an exported header directive" do
      irModule ←
        translateModuleWith
          (directivesFor [((Name "foo", Nothing), Inliner.ModeAnnotation Always)])
          ["@inline export foo arity=1"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just Always)

    it "an exported header directive applies when nothing overrides it" do
      irModule ←
        translateModule
          ["@inline export foo arity=1"]
          [Cfn.NonRec ann (PS.Ident "foo") (cfnImportedRef "bar")]
      bindingRootAnn (Name "foo") irModule `shouldBe` Just (Just (Arity 1))

    it "accepts always and never on a foreign binding" do
      irModule ←
        translateForeign
          ["@inline ffi never"]
          [PS.Ident "ffi"]
      moduleForeigns irModule `shouldBe` [(Just Never, Name "ffi")]

    it "rejects arity on a foreign binding" do
      translate mempty ["@inline ffi arity=1"] [] [PS.Ident "ffi"]
        `shouldFailWith` "foreign"

    it "rejects an accessor directive on a foreign binding" do
      translate mempty ["@inline ffi.method never"] [] [PS.Ident "ffi"]
        `shouldFailWith` "foreign"

  describe "case expressions" do
    describe "singular" do
      it "null binder" do
        representedCase
          [cfnBool True]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnNullB]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= (`shouldBe` literalInt 1)

      let defaultAlternative =
            Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnNullB]
              , caseAlternativeResult = Right $ cfnInt 0
              }

      it "literalInt literal binder" do
        representedCase
          [cfnInt 3]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [cfnLitB (Cfn.NumericLiteral (Left 9))]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          , defaultAlternative
          ]
          >>= ( `shouldBe`
                  ifThenElse (literalInt 9 `eq` literalInt 3) (literalInt 1) (literalInt 0)
              )

      it "literalFloat literal binder" do
        representedCase
          [cfnFloat 3.0]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [cfnLitB (Cfn.NumericLiteral (Right 9.0))]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          , defaultAlternative
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalFloat 9.0 `eq` literalFloat 3.0)
                    (literalInt 1)
                    (literalInt 0)
              )

      it "char literal binder" do
        representedCase
          [cfnCharE 'x']
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [cfnLitB (cfnCharL 'c')]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          , defaultAlternative
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalChar 'c' `eq` literalChar 'x')
                    (literalInt 1)
                    (literalInt 0)
              )

      it "array literal binder" do
        let x = refLocal (Name "x")
            expectedResult =
              ifThenElse
                (literalInt 3 `eq` arrayLength x)
                ( ifThenElse
                    (literalChar 'a' `eq` arrayIndex x 0)
                    ( ifThenElse
                        (literalChar 'b' `eq` arrayIndex x 1)
                        ( ifThenElse
                            (literalInt 2 `eq` arrayLength (arrayIndex x 2))
                            ( ifThenElse
                                (literalChar 'c' `eq` arrayIndex (arrayIndex x 2) 0)
                                ( ifThenElse
                                    ( literalChar 'd'
                                        `eq` arrayIndex (arrayIndex x 2) 1
                                    )
                                    (literalInt 1)
                                    (literalInt 0)
                                )
                                (literalInt 0)
                            )
                            (literalInt 0)
                        )
                        (literalInt 0)
                    )
                    (literalInt 0)
                )
                (literalInt 0)

        representedCase
          [cfnRef "x"]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ Cfn.LiteralBinder
                      ann
                      ( Cfn.ArrayLiteral
                          [ cfnLitB (cfnCharL 'a')
                          , cfnLitB (cfnCharL 'b')
                          , cfnLitB $
                              Cfn.ArrayLiteral
                                [ cfnLitB (cfnCharL 'c')
                                , cfnLitB (cfnCharL 'd')
                                ]
                          ]
                      )
                  ]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          , defaultAlternative
          ]
          >>= (`shouldBe` expectedResult)

      it "object literal binder" do
        representedCase
          [cfnRef "x"]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ Cfn.LiteralBinder
                      ann
                      ( Cfn.ObjectLiteral
                          [ ("foo", cfnLitB (cfnCharL 'a'))
                          ,
                            ( "bar"
                            , Cfn.LiteralBinder
                                ann
                                ( Cfn.ObjectLiteral
                                    [
                                      ( "baz"
                                      , cfnLitB (cfnCharL 'b')
                                      )
                                    ]
                                )
                            )
                          ]
                      )
                  ]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          , defaultAlternative
          ]
          >>= ( `shouldBe`
                  let x = refLocal (Name "x")
                   in ifThenElse
                        (literalChar 'a' `eq` objectProp x (PropName "foo"))
                        ( ifThenElse
                            ( literalChar 'b'
                                `eq` objectProp
                                  (objectProp x (PropName "bar"))
                                  (PropName "baz")
                            )
                            (literalInt 1)
                            (literalInt 0)
                        )
                        (literalInt 0)
              )

      it "local reference is not created for literal int expression" do
        representedCase
          [cfnInt 1]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnLitB (Cfn.NumericLiteral (Left 2))]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalInt 2 `eq` literalInt 1)
                    (literalInt 1)
                    (exception "No patterns matched")
              )

      it "local reference is not created for literal literalFloat expression" do
        representedCase
          [cfnFloat 1.0]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [cfnLitB (Cfn.NumericLiteral (Right 2.0))]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalFloat 2.0 `eq` literalFloat 1.0)
                    (literalInt 1)
                    (exception "No patterns matched")
              )

      it "local reference is not created for literal literalChar expression" do
        representedCase
          [cfnCharE 'x']
          [ Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnLitB (cfnCharL 'a')]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalChar 'a' `eq` literalChar 'x')
                    (literalInt 1)
                    (exception "No patterns matched")
              )

      it "local reference is not created for literal bool expression" do
        representedCase
          [cfnBool True]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnLitB (Cfn.BooleanLiteral False)]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalBool False `eq` literalBool True)
                    (literalInt 1)
                    (exception "No patterns matched")
              )

      it "local reference is created for array literal expression" do
        representedCase
          [cfnArray []]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnLitB (Cfn.BooleanLiteral False)]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  let1
                    (Name "e0")
                    (literalArray [])
                    ( ifThenElse
                        (literalBool False `eq` refLocal (Name "e0"))
                        (literalInt 1)
                        (exception "No patterns matched")
                    )
              )

      it "local reference is created for object literal expression" do
        representedCase
          [cfnObject [("a", cfnInt 1)]]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnLitB
                      ( Cfn.ObjectLiteral
                          [ ("a", cfnLitB (Cfn.NumericLiteral (Left 2)))
                          ]
                      )
                  ]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  let1
                    (Name "e0")
                    (literalObject [(PropName "a", literalInt 1)])
                    ( ifThenElse
                        ( literalInt 2
                            `eq` objectProp
                              (refLocal (Name "e0"))
                              (PropName "a")
                        )
                        (literalInt 1)
                        (exception "No patterns matched")
                    )
              )

      it "local reference is not created for reference expression" do
        representedCase
          [cfnRef "r"]
          [ Cfn.CaseAlternative
              { caseAlternativeBinders = [cfnLitB (Cfn.BooleanLiteral False)]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalBool False `eq` refLocal (Name "r"))
                    (literalInt 1)
                    (exception "No patterns matched")
              )

    describe "plural" do
      it "two binders compiles to a nested if" do
        {-

        case 'x', 'y' of         if 'a' == 'x' then
          'a', 'b' -> 1    ==>     if 'b' == 'y' then
          'e',  _  -> 0              1
                                   else
                                     if 'e' == 'x' then
                                      0
                                     else
                                      exception "no patterns matched"
                                 else
                                   if 'e' == 'x' then
                                     0
                                   else
                                     exception "no patterns matched"

        -}
        representedCase
          [cfnCharE 'x', cfnCharE 'y']
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnLitB (cfnCharL 'a')
                  , cfnLitB (cfnCharL 'b')
                  ]
              , caseAlternativeResult = Right $ cfnInt 1
              }
          , Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnLitB (cfnCharL 'e')
                  , cfnNullB
                  ]
              , caseAlternativeResult = Right $ cfnInt 0
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalChar 'a' `eq` literalChar 'x')
                    ( ifThenElse
                        (literalChar 'b' `eq` literalChar 'y')
                        (literalInt 1)
                        ( ifThenElse
                            (literalChar 'e' `eq` literalChar 'x')
                            (literalInt 0)
                            (exception "No patterns matched")
                        )
                    )
                    ( ifThenElse
                        (literalChar 'e' `eq` literalChar 'x')
                        (literalInt 0)
                        (exception "No patterns matched")
                    )
              )

      it "Used var binders are pushed to the RHS" do
        representedCase
          [cfnCharE 't', cfnCharE 'z']
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnVarB (PS.Ident "x")
                  , cfnLitB (cfnCharL 'a')
                  ]
              , caseAlternativeResult = Right $ cfnRef "x"
              }
          , Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnLitB (cfnCharL 'b')
                  , cfnVarB (PS.Ident "y")
                  ]
              , caseAlternativeResult = Right $ cfnRef "y"
              }
          , Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnNullB
                  , cfnNullB
                  ]
              , caseAlternativeResult = Right $ cfnInt 3
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalChar 'a' `eq` literalChar 'z')
                    (let1 (Name "x") (literalChar 't') (refLocal (Name "x")))
                    ( ifThenElse
                        (literalChar 'b' `eq` literalChar 't')
                        (let1 (Name "y") (literalChar 'z') (refLocal (Name "y")))
                        (literalInt 3)
                    )
              )

      it "named wildcard binders compile to a let" do
        representedCase
          [cfnCharE 'x', cfnCharE 'y']
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnNamB (PS.Ident "v") cfnNullB
                  , cfnNamB (PS.Ident "z") cfnNullB
                  ]
              , caseAlternativeResult = Right $ cfnRef "z"
              }
          ]
          >>= ( `shouldBe`
                  lets
                    ( Standalone (noAnn, Name "z", literalChar 'y')
                        :| [Standalone (noAnn, Name "v", literalChar 'x')]
                    )
                    (refLocal (Name "z"))
              )

      it "named binders compile to a let bindings" do
        representedCase
          [cfnCharE 'x', cfnCharE 'y']
          [ Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnNamB (PS.Ident "a") (cfnLitB (cfnCharL 'a'))
                  , cfnNamB (PS.Ident "b") (cfnLitB (cfnCharL 'b'))
                  ]
              , caseAlternativeResult =
                  Right $ cfnApp (cfnRef "a") (cfnRef "b")
              }
          , Cfn.CaseAlternative
              { caseAlternativeBinders =
                  [ cfnNamB (PS.Ident "o1") cfnNullB
                  , cfnNamB (PS.Ident "o2") cfnNullB
                  ]
              , caseAlternativeResult =
                  Right $ cfnApp (cfnRef "o2") (cfnRef "o1")
              }
          ]
          >>= ( `shouldBe`
                  ifThenElse
                    (literalChar 'a' `eq` literalChar 'x')
                    ( ifThenElse
                        (literalChar 'b' `eq` literalChar 'y')
                        ( lets
                            ( Standalone (noAnn, Name "b", literalChar 'y')
                                :| [Standalone (noAnn, Name "a", literalChar 'x')]
                            )
                            ( application
                                (refLocal (Name "a"))
                                (refLocal (Name "b"))
                            )
                        )
                        ( lets
                            ( Standalone (noAnn, Name "o2", literalChar 'y')
                                :| [Standalone (noAnn, Name "o1", literalChar 'x')]
                            )
                            ( application
                                (refLocal (Name "o2"))
                                (refLocal (Name "o1"))
                            )
                        )
                    )
                    ( lets
                        ( Standalone (noAnn, Name "o2", literalChar 'y')
                            :| [Standalone (noAnn, Name "o1", literalChar 'x')]
                        )
                        ( application
                            (refLocal (Name "o2"))
                            (refLocal (Name "o1"))
                        )
                    )
              )

  describe "collectDataDeclarations" do
    it "classifies data types regardless of constructor order" do
      let cfnCtor tyName ctorName =
            Cfn.Constructor
              ann
              (PS.ProperName tyName)
              (PS.ProperName ctorName)
              []
          bind ident = Cfn.NonRec ann (PS.Ident ident)
          -- Constructor C of type U is interleaved between T's two
          -- constructors, so adjacency-based grouping would split T into
          -- singleton groups and misclassify it as a product type.
          cfnMod =
            cfnModule
              { Cfn.moduleBindings =
                  [ bind "A" (cfnCtor "T" "A")
                  , bind "C" (cfnCtor "U" "C")
                  , bind "B" (cfnCtor "T" "B")
                  ]
              }
      collectDataDeclarations (Map.singleton (PS.ModuleName "M") cfnMod)
        `shouldBe` Map.fromList
          [
            ( (PS.ModuleName "M", TyName "T")
            , (SumType, Map.fromList [(CtorName "A", []), (CtorName "B", [])])
            )
          ,
            ( (PS.ModuleName "M", TyName "U")
            , (ProductType, Map.fromList [(CtorName "C", [])])
            )
          ]

--------------------------------------------------------------------------------
-- Helper functions ------------------------------------------------------------

representedCase
  ∷ MonadFail m
  ⇒ [Cfn.Expr Cfn.Ann]
  → [Cfn.CaseAlternative Cfn.Ann]
  → m Exp
representedCase es alts = runRepresentM (mkCase noAnn es (NE.fromList alts))

runRepresentM ∷ MonadFail m ⇒ RepM Exp → m Exp
runRepresentM rm =
  either
    (fail . show)
    (pure . snd)
    ( runRepM
        Context
          { contextModule = cfnModule
          , contextDataTypes = mempty
          , lastGeneratedNameIndex = 0
          , needsRuntimeLazy = Any False
          , annotations = mempty
          , headerTargets = mempty
          }
        rm
    )

translateModule ∷ MonadFail m ⇒ [Text] → [Cfn.Bind Cfn.Ann] → m Module
translateModule = translateModuleWith mempty

translateModuleWith
  ∷ MonadFail m
  ⇒ Inliner.Directives
  → [Text]
  → [Cfn.Bind Cfn.Ann]
  → m Module
translateModuleWith directives commentLines bindings =
  either fail pure $ translate directives commentLines bindings []

translateForeign ∷ MonadFail m ⇒ [Text] → [PS.Ident] → m Module
translateForeign commentLines foreigns =
  either fail pure $ translate mempty commentLines [] foreigns

translate
  ∷ Inliner.Directives
  → [Text]
  → [Cfn.Bind Cfn.Ann]
  → [PS.Ident]
  → Either String Module
translate directives commentLines bindings foreigns =
  bimap show snd $
    mkModule
      directives
      cfnModule
        { Cfn.moduleComments = LineComment <$> commentLines
        , Cfn.moduleBindings = bindings
        , Cfn.moduleForeign = foreigns
        }
      mempty

directivesFor ∷ [(Inliner.Target, Inliner.Mode)] → Inliner.Directives
directivesFor entries =
  one (PS.ModuleName "M", Map.fromList entries)

shouldFailWith ∷ HasCallStack ⇒ Either String Module → String → Expectation
shouldFailWith result needle = case result of
  Left err → err `shouldSatisfy` (needle `List.isInfixOf`)
  Right _ → expectationFailure "translation unexpectedly succeeded"

-- | The root annotation of a standalone module binding, or 'Nothing'
-- when no binding of this name exists.
bindingRootAnn ∷ Name → Module → Maybe Ann
bindingRootAnn name Module {moduleBindings} =
  listToMaybe
    [getAnn expr | Standalone (_ann, n, expr) ← moduleBindings, n == name]

-- | The annotation of an object-literal field inside a standalone module
-- binding, found at any lambda/let depth; 'Nothing' when no such field
-- exists.
fieldAnn ∷ Name → PropName → Module → Maybe Ann
fieldAnn name label irModule = do
  root ← listToMaybe
    [ expr
    | Standalone (_ann, n, expr) ← moduleBindings irModule
    , n == name
    ]
  go root
 where
  go = \case
    AbsN _a _params body → go body
    Let _a _binds body → go body
    LiteralObject _a props → getAnn <$> List.lookup label props
    _ → Nothing

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

ann ∷ Cfn.Ann
ann = Nothing

cfnModule ∷ ∀ {a}. Cfn.Module a
cfnModule =
  Cfn.Module
    { moduleName = PS.ModuleName "M"
    , moduleComments = mempty
    , modulePath = "M.purs"
    , moduleImports = mempty
    , moduleExports = mempty
    , moduleReExports = mempty
    , moduleForeign = mempty
    , moduleBindings = mempty
    }

cfnQualifyModule ∷ a → PS.Qualified a
cfnQualifyModule = PS.Qualified (PS.ByModuleName (PS.ModuleName "ModuleName"))

cfnLocalIdent ∷ Text → PS.Qualified PS.Ident
cfnLocalIdent = PS.Qualified (PS.BySourcePos (PS.SourcePos 0 0)) . PS.Ident

cfnRef ∷ Text → Cfn.Expr Cfn.Ann
cfnRef = Cfn.Var ann . cfnLocalIdent

cfnImportedRef ∷ Text → Cfn.Expr Cfn.Ann
cfnImportedRef = Cfn.Var ann . cfnQualifyModule . PS.Ident

cfnBool ∷ Bool → Cfn.Expr Cfn.Ann
cfnBool b = Cfn.Literal ann (Cfn.BooleanLiteral b)

cfnInt ∷ Integer → Cfn.Expr Cfn.Ann
cfnInt i = Cfn.Literal ann (Cfn.NumericLiteral (Left i))

cfnFloat ∷ Double → Cfn.Expr Cfn.Ann
cfnFloat f = Cfn.Literal ann (Cfn.NumericLiteral (Right f))

cfnCharE ∷ Char → Cfn.Expr Cfn.Ann
cfnCharE = Cfn.Literal ann . cfnCharL

cfnCharL ∷ Char → Cfn.Literal a
cfnCharL = Cfn.CharLiteral

cfnArray ∷ [Cfn.Expr Cfn.Ann] → Cfn.Expr Cfn.Ann
cfnArray a = Cfn.Literal ann (Cfn.ArrayLiteral a)

cfnObject ∷ [(Text, Cfn.Expr Cfn.Ann)] → Cfn.Expr Cfn.Ann
cfnObject o = Cfn.Literal ann $ Cfn.ObjectLiteral (first PS.mkString <$> o)

cfnLitB ∷ Cfn.Literal (Cfn.Binder Cfn.Ann) → Cfn.Binder Cfn.Ann
cfnLitB = Cfn.LiteralBinder ann

cfnVarB ∷ PS.Ident → Cfn.Binder Cfn.Ann
cfnVarB = Cfn.VarBinder ann

cfnNamB ∷ PS.Ident → Cfn.Binder Cfn.Ann → Cfn.Binder Cfn.Ann
cfnNamB = Cfn.NamedBinder ann

cfnNullB ∷ Cfn.Binder Cfn.Ann
cfnNullB = Cfn.NullBinder ann

cfnApp ∷ Cfn.Expr Cfn.Ann → Cfn.Expr Cfn.Ann → Cfn.Expr Cfn.Ann
cfnApp = Cfn.App ann

let1 ∷ Name → Exp → Exp → Exp
let1 n e = lets (pure (Standalone (noAnn, n, e)))
