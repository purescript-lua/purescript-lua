module Language.PureScript.Backend.IR.AbsorbEffectThunk.Spec where

import Language.PureScript.Backend.IR.AbsorbEffectThunk (absorbEffectThunk)
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
  , pattern EffectRunArg
  )
import Test.Hspec (Spec, describe, it, shouldBe)

spec ∷ Spec
spec = describe "IR AbsorbEffectThunk" do
  it "extends a worker whose only reference is a forced site" do
    let m =
          moduleOf
            [Standalone (qn "f$w", thunkWorker2)]
            [(Name "main", forcedSite)]
    absorbEffectThunk m
      `shouldBe` moduleOf
        [Standalone (qn "f$w", extendedWorker2)]
        [(Name "main", extendedCall)]

  it "grows the wrapper that delegates to the worker" do
    let m =
          moduleOf
            [ Standalone (qn "f$w", thunkWorker2)
            , Standalone (qn "f", wrapper2)
            ]
            [(Name "main", forcedSite)]
    absorbEffectThunk m
      `shouldBe` moduleOf
        [ Standalone (qn "f$w", extendedWorker2)
        , Standalone (qn "f", grownWrapper2)
        ]
        [(Name "main", extendedCall)]

  it "declines a worker with no forced site" do
    -- The wrapper's delegate call alone buys nothing and would grow the
    -- wrapper for free.
    let m =
          moduleOf
            [ Standalone (qn "f$w", thunkWorker2)
            , Standalone (qn "f", wrapper2)
            ]
            [(Name "main", application f (literalInt 1))]
    absorbEffectThunk m `shouldBe` m

  it "declines a worker whose saturated call is not forced" do
    -- The action is bound and run later: the wider arity would make the
    -- binding itself run the effect.
    let held = Name "held"
        m =
          moduleOf
            [Standalone (qn "f$w", thunkWorker2)]
            [ (Name "main", forcedSite)
            ,
              ( Name "later"
              , lets
                  (Standalone (noAnn, held, saturatedCall) :| [])
                  (application (refLocal held) (EffectRunArg noAnn))
              )
            ]
    absorbEffectThunk m `shouldBe` m

  it "declines a worker passed on as a value" do
    let m =
          moduleOf
            [Standalone (qn "f$w", thunkWorker2)]
            [ (Name "main", forcedSite)
            , (Name "value", fw)
            ]
    absorbEffectThunk m `shouldBe` m

  it "extends a Let-bound worker in place" do
    let gw = Name "g$w"
        localWorker =
          abstractionN
            (paramNamed (Name "a") :| [paramNamed (Name "b")])
            ( abstraction
                paramUnused
                (eq (refLocal (Name "a")) (refLocal (Name "b")))
            )
        localSite =
          application
            (applicationN (refLocal gw) (literalInt 1 :| [literalInt 2]))
            (EffectRunArg noAnn)
        siteOf worker = lets (Standalone (noAnn, gw, worker) :| [])
        m = moduleOf [Standalone (qn "h", siteOf localWorker localSite)] []
    absorbEffectThunk m
      `shouldBe` moduleOf
        [ Standalone
            ( qn "h"
            , siteOf
                ( abstractionN
                    ( paramNamed (Name "a")
                        :| [paramNamed (Name "b"), paramUnused]
                    )
                    (eq (refLocal (Name "a")) (refLocal (Name "b")))
                )
                ( applicationN
                    (refLocal gw)
                    (literalInt 1 :| [literalInt 2, EffectRunArg noAnn])
                )
            )
        ]
        []

--------------------------------------------------------------------------------
-- Fixtures --------------------------------------------------------------------

mn ∷ ModuleName
mn = moduleNameFromString "Test"

qn ∷ Text → QName
qn = QName mn . Name

f ∷ Exp
f = refImported mn (Name "f")

fw ∷ Exp
fw = refImported mn (Name "f$w")

{- | @λa. λb. λ_. a == b@ — the worker as magic-do leaves it: n-ary in
its real arguments, its body the thunk.
-}
thunkWorker2 ∷ Exp
thunkWorker2 =
  abstractionN
    (paramNamed (Name "a") :| [paramNamed (Name "b")])
    (abstraction paramUnused (eq (refLocal (Name "a")) (refLocal (Name "b"))))

-- | @λa. λb. λ_. a == b@ with the thunk's parameter absorbed.
extendedWorker2 ∷ Exp
extendedWorker2 =
  abstractionN
    (paramNamed (Name "a") :| [paramNamed (Name "b"), paramUnused])
    (eq (refLocal (Name "a")) (refLocal (Name "b")))

-- | @f$w(1, 2)@ — saturated in the real arguments, the action itself.
saturatedCall ∷ Exp
saturatedCall = applicationN fw (literalInt 1 :| [literalInt 2])

-- | @f$w(1, 2)(run)@ — the statement site magic-do produces.
forcedSite ∷ Exp
forcedSite = application saturatedCall (EffectRunArg noAnn)

-- | @f$w(1, 2, run)@ — the same site as one call.
extendedCall ∷ Exp
extendedCall =
  applicationN fw (literalInt 1 :| [literalInt 2, EffectRunArg noAnn])

-- | @λf$p1. λf$p2. f$w(f$p1, f$p2)@ — the curried delegate.
wrapper2 ∷ Exp
wrapper2 =
  abstraction
    (paramNamed (Name "f$p1"))
    ( abstraction
        (paramNamed (Name "f$p2"))
        (applicationN fw (refLocal (Name "f$p1") :| [refLocal (Name "f$p2")]))
    )

-- | The delegate grown by the parameter that now plays the thunk's role.
grownWrapper2 ∷ Exp
grownWrapper2 =
  abstraction
    (paramNamed (Name "f$p1"))
    ( abstraction
        (paramNamed (Name "f$p2"))
        ( abstraction
            (paramNamed (Name "f$p2$t"))
            ( applicationN
                fw
                ( refLocal (Name "f$p1")
                    :| [refLocal (Name "f$p2"), refLocal (Name "f$p2$t")]
                )
            )
        )
    )

moduleOf ∷ [Grouping (QName, Exp)] → [(Name, Exp)] → UberModule
moduleOf bindings exports =
  UberModule
    { uberModuleBindings = bindings
    , uberModuleForeigns = []
    , uberModuleExports = exports
    }
