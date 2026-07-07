module Language.PureScript.Backend.IR.Uncurry.Spec where

import Data.Set qualified as Set
import Language.PureScript.Backend.IR.Inliner qualified as Inline
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (..)
  , QName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , RawExp (..)
  , WasRewritten (..)
  , abstraction
  , abstractionN
  , application
  , applicationN
  , eq
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , paramUnused
  , refImported
  , refLocal
  , setAnn
  )
import Language.PureScript.Backend.IR.Uncurry (uncurryWorkerWrapper)
import Test.Hspec (Spec, describe, it, shouldBe)

spec ∷ Spec
spec = describe "IR Uncurry (worker/wrapper)" do
  it "splits a saturated binding into worker and wrapper, rewriting the site" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", saturatedCall)]
    uncurryWorkerWrapper mempty m
      `shouldBe` ( moduleOf
                     [ Standalone (qn "f$w", worker2)
                     , Standalone (qn "f", wrapper2)
                     ]
                     [(Name "main", applicationN fw (literalInt 1 :| [literalInt 2]))]
                 , Rewritten
                 )

  it "leaves a binding with no saturated application untouched" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", application f (literalInt 1))]
    uncurryWorkerWrapper mempty m `shouldBe` (m, Unmodified)

  it "keeps partial applications going through the wrapper" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [ (Name "main", saturatedCall)
            , (Name "partial", application f (literalInt 1))
            ]
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleExports m'
      `shouldBe` [ (Name "main", applicationN fw (literalInt 1 :| [literalInt 2]))
                 , (Name "partial", application f (literalInt 1))
                 ]

  it "rewrites the inner node of an over-application" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", application saturatedCall (literalInt 3))]
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleExports m'
      `shouldBe` [
                   ( Name "main"
                   , application
                       (applicationN fw (literalInt 1 :| [literalInt 2]))
                       (literalInt 3)
                   )
                 ]

  it "uncurries a recursive-group member and its self-call" do
    let body =
          application
            (application f (refLocal (Name "a")))
            (refLocal (Name "b"))
        member =
          abstraction
            (paramNamed (Name "a"))
            (abstraction (paramNamed (Name "b")) body)
        m =
          moduleOf
            [RecursiveGroup ((qn "f", member) :| [])]
            [(Name "main", saturatedCall)]
        workerBody =
          applicationN
            fw
            (refLocal (Name "a") :| [refLocal (Name "b")])
        worker =
          abstractionN
            (paramNamed (Name "a") :| [paramNamed (Name "b")])
            workerBody
    uncurryWorkerWrapper mempty m
      `shouldBe` ( moduleOf
                     [ RecursiveGroup
                         ((qn "f$w", worker) :| [(qn "f", wrapper2)])
                     ]
                     [(Name "main", applicationN fw (literalInt 1 :| [literalInt 2]))]
                 , Rewritten
                 )

  it "uncurries a local Let binding in place" do
    let go = Name "go"
        goDef =
          abstraction
            (paramNamed (Name "a"))
            ( abstraction
                (paramNamed (Name "b"))
                (eq (refLocal (Name "a")) (refLocal (Name "b")))
            )
        site =
          application
            (application (refLocal go) (literalInt 1))
            (literalInt 2)
        m =
          moduleOf
            [Standalone (qn "g", lets (Standalone (noAnn, go, goDef) :| []) site)]
            []
        goWorker =
          abstractionN
            (paramNamed (Name "a") :| [paramNamed (Name "b")])
            (eq (refLocal (Name "a")) (refLocal (Name "b")))
        goWrapper =
          abstraction
            (paramNamed (Name "go$p1"))
            ( abstraction
                (paramNamed (Name "go$p2"))
                ( applicationN
                    (refLocal (Name "go$w"))
                    (refLocal (Name "go$p1") :| [refLocal (Name "go$p2")])
                )
            )
        expected =
          lets
            ( Standalone (noAnn, Name "go$w", goWorker)
                :| [Standalone (noAnn, go, goWrapper)]
            )
            ( applicationN
                (refLocal (Name "go$w"))
                (literalInt 1 :| [literalInt 2])
            )
    uncurryWorkerWrapper mempty m
      `shouldBe` (moduleOf [Standalone (qn "g", expected)] [], Rewritten)

  it "does not split an @inline never binding" do
    let m =
          moduleOf
            [Standalone (qn "f", def2)]
            [(Name "main", saturatedCall)]
    uncurryWorkerWrapper (Set.singleton (qn "f")) m
      `shouldBe` (m, Unmodified)

  it "keeps a trailing unused parameter unused in the worker" do
    let def =
          abstraction
            (paramNamed (Name "x"))
            (abstraction paramUnused (refLocal (Name "x")))
        m =
          moduleOf
            [Standalone (qn "f", def)]
            [(Name "main", saturatedCall)]
        worker =
          abstractionN
            (paramNamed (Name "x") :| [paramUnused])
            (refLocal (Name "x"))
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleBindings m'
      `shouldBe` [ Standalone (qn "f$w", worker)
                 , Standalone (qn "f", wrapper2)
                 ]

  it "names an interior unused parameter of the worker" do
    -- ParamUnused must stay a trailing run (Note [n-ary abstraction]),
    -- so an unused parameter followed by a named one becomes a fresh
    -- never-referenced binder.
    let def =
          abstraction
            paramUnused
            (abstraction (paramNamed (Name "y")) (refLocal (Name "y")))
        m =
          moduleOf
            [Standalone (qn "f", def)]
            [(Name "main", saturatedCall)]
        worker =
          abstractionN
            (paramNamed (Name "f$u1") :| [paramNamed (Name "y")])
            (refLocal (Name "y"))
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleBindings m'
      `shouldBe` [ Standalone (qn "f$w", worker)
                 , Standalone (qn "f", wrapper2)
                 ]

  it "preserves the wrapper's root annotation" do
    let m =
          moduleOf
            [Standalone (qn "f", setAnn (Just Inline.Always) def2)]
            [(Name "main", saturatedCall)]
    let (m', _) = uncurryWorkerWrapper mempty m
    uberModuleBindings m'
      `shouldBe` [ Standalone (qn "f$w", worker2)
                 , Standalone (qn "f", setAnn (Just Inline.Always) wrapper2)
                 ]

  it "scopes local candidates per top-level site" do
    -- Two sites both bind a local `go`: a saturated site in one site
    -- must not qualify the same-named binder of the other site.
    let go = Name "go"
        goDef =
          abstraction
            (paramNamed (Name "a"))
            (abstraction (paramNamed (Name "b")) (refLocal (Name "a")))
        saturated =
          application (application (refLocal go) (literalInt 1)) (literalInt 2)
        partial = application (refLocal go) (literalInt 1)
        siteWith = lets (Standalone (noAnn, go, goDef) :| [])
        m =
          moduleOf
            [ Standalone (qn "g1", siteWith saturated)
            , Standalone (qn "g2", siteWith partial)
            ]
            []
    let (m', _) = uncurryWorkerWrapper mempty m
        exprOf name =
          fromMaybe (error "binding missing") $
            listToMaybe
              [e | Standalone (q, e) ← uberModuleBindings m', q == qn name]
    -- g1's go is split…
    case exprOf "g1" of
      Let _ binds _ → length (toList binds) `shouldBe` 2
      _ → error "g1 lost its Let"
    -- …g2's same-named go is not.
    exprOf "g2" `shouldBe` siteWith partial

--------------------------------------------------------------------------------
-- Fixture ---------------------------------------------------------------------

mn ∷ ModuleName
mn = moduleNameFromString "M"

qn ∷ Text → QName
qn = QName mn . Name

f ∷ Exp
f = refImported mn (Name "f")

fw ∷ Exp
fw = refImported mn (Name "f$w")

-- | @λa. λb. a == b@ — the curried two-parameter definition.
def2 ∷ Exp
def2 =
  abstraction
    (paramNamed (Name "a"))
    ( abstraction
        (paramNamed (Name "b"))
        (eq (refLocal (Name "a")) (refLocal (Name "b")))
    )

-- | The worker 'def2' splits into.
worker2 ∷ Exp
worker2 =
  abstractionN
    (paramNamed (Name "a") :| [paramNamed (Name "b")])
    (eq (refLocal (Name "a")) (refLocal (Name "b")))

-- | The wrapper @f@ becomes: @λf$p1. λf$p2. f$w(f$p1, f$p2)@.
wrapper2 ∷ Exp
wrapper2 =
  abstraction
    (paramNamed (Name "f$p1"))
    ( abstraction
        (paramNamed (Name "f$p2"))
        ( applicationN
            fw
            (refLocal (Name "f$p1") :| [refLocal (Name "f$p2")])
        )
    )

-- | @f(1)(2)@ — a saturated curried call of the arity-2 candidate.
saturatedCall ∷ Exp
saturatedCall =
  application (application f (literalInt 1)) (literalInt 2)

moduleOf ∷ [Grouping (QName, Exp)] → [(Name, Exp)] → UberModule
moduleOf bindings exports =
  UberModule
    { uberModuleBindings = bindings
    , uberModuleForeigns = []
    , uberModuleExports = exports
    }
