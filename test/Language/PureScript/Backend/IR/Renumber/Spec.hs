module Language.PureScript.Backend.IR.Renumber.Spec where

import Data.List qualified as List
import Hedgehog (forAll, (===))
import Language.PureScript.Backend.IR.Gen qualified as Gen
import Language.PureScript.Backend.IR.Linker (UberModule (..))
import Language.PureScript.Backend.IR.Linter
  ( lintUniqueBinders
  , lintWellScoped
  )
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , QName (..)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Renumber (renumberUberModule)
import Language.PureScript.Backend.IR.SpecUtils
  ( applyPassToExpression
  , emptyUberModule
  )
import Language.PureScript.Backend.IR.Supply (SupplyM, freshName, runSupply)
import Language.PureScript.Backend.IR.Types
  ( Exp
  , Grouping (..)
  , RawExp (ForeignImport)
  , abstraction
  , application
  , freshenBinders
  , lets
  , literalInt
  , noAnn
  , paramNamed
  , refLocal
  )
import Language.PureScript.Backend.IR.Uniquify (uniquifyNamesInExpr)
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Expectations.Pretty (shouldBe)
import Test.Hspec.Hedgehog.Extended (prop)

spec ∷ Spec
spec = describe "IR renumbering of minted binders (issue #338)" do
  describe "a site's names are invariant under supply history" do
    -- The indices the pipeline mints depend on how much supply ran out
    -- before the minting pass reached the site, so the same site emerges
    -- with different names when unrelated code upstream mints more or
    -- fewer of them. Renumbering must map both spellings to one.
    it "suffix-minted binders (base$N)" do
      renumbered (letWithMintedLocals 100)
        `shouldBe` renumbered (letWithMintedLocals 0)

    it "prefix-minted binders ($tagN)" do
      renumbered (letWithMintedTags 100)
        `shouldBe` renumbered (letWithMintedTags 0)

    prop 300 "any freshened site, at any supply offset" do
      e ← forAll Gen.scopedExp
      let atOffset k =
            renumbered
              (runSupply (burn k *> freshenBinders (uniquifyNamesInExpr e)))
      atOffset 1000 === atOffset 0

  describe "each site is renumbered from its own allocation" do
    -- Per-site allocation is what confines a change: were the indices
    -- handed out module-wide, a site minting one more name would shift
    -- every site printed after it.
    it "a site's names ignore what earlier sites consumed" do
      secondSiteAfter (letWithMintedLocals 0)
        `shouldBe` secondSiteAfter (soleMintedLocal 0)

    it "sibling sites reuse the same renumbered names" do
      let sites = uberModuleExports (renumberUberModule twoSiteModule)
      fmap snd sites `shouldBe` [renumbered site | (_name, site) ← twoSites]

  describe "renumberUberModule" do
    it "renumbers a suffix-minted binder and its references" do
      renumbered (boundTo "x$223" (literalInt 1) (refLocal (Name "x$223")))
        `shouldBe` boundTo "x$0" (literalInt 1) (refLocal (Name "x$0"))

    it "allocates per base name in first-occurrence order" do
      renumbered
        ( lets
            ( Standalone (noAnn, Name "v$1437", literalInt 1)
                :| [Standalone (noAnn, Name "v$921", refLocal (Name "v$1437"))]
            )
            (refLocal (Name "v$921"))
        )
        `shouldBe` lets
          ( Standalone (noAnn, Name "v$0", literalInt 1)
              :| [Standalone (noAnn, Name "v$1", refLocal (Name "v$0"))]
          )
          (refLocal (Name "v$1"))

    it "renumbers a prefix-minted binder" do
      renumbered (boundTo "$cse1413" (literalInt 1) (refLocal (Name "$cse1413")))
        `shouldBe` boundTo "$cse0" (literalInt 1) (refLocal (Name "$cse0"))

    it "keeps a derived name in step with the binder it embeds" do
      -- The uncurried worker of $kont7 spells the index mid-name, and
      -- must land on the same index as the helper it is derived from.
      renumbered
        ( lets
            ( Standalone
                ( noAnn
                , Name "$kont7"
                , abstraction (paramNamed (Name "n$9")) (refLocal (Name "n$9"))
                )
                :| [ Standalone
                       (noAnn, Name "$kont7$w", refLocal (Name "$kont7"))
                   ]
            )
            (refLocal (Name "$kont7$w"))
        )
        `shouldBe` lets
          ( Standalone
              ( noAnn
              , Name "$kont0"
              , abstraction (paramNamed (Name "n$0")) (refLocal (Name "n$0"))
              )
              :| [Standalone (noAnn, Name "$kont0$w", refLocal (Name "$kont0"))]
          )
          (refLocal (Name "$kont0$w"))

    it "leaves structural indices and source spellings alone" do
      -- Uncurrying's worker and parameter suffixes, call-pattern
      -- specialization's shape suffix, uniquification's digit suffix,
      -- magic-do's marker and a source name that merely ends in a digit.
      unchanged $
        lets
          ( Standalone (noAnn, Name "add3", literalInt 1)
              :| [ Standalone (noAnn, Name "f$w", literalInt 2)
                 , Standalone (noAnn, Name "f$p1", literalInt 3)
                 , Standalone (noAnn, Name "pong$sc1Tuple", literalInt 4)
                 , Standalone (noAnn, Name "x0", literalInt 5)
                 , Standalone (noAnn, Name "$magicDoRun", literalInt 6)
                 ]
          )
          (refLocal (Name "x0"))

    it "leaves a foreign import's export keys alone" do
      unchanged $
        ForeignImport
          noAnn
          (moduleNameFromString "Foreign.M")
          "m.lua"
          [(noAnn, Name "key$5")]

    prop 300 "is the identity on sites without minted names" do
      e ← forAll Gen.scopedExp
      renumbered e === e

    prop 300 "is idempotent" do
      e ← forAll (freshened <$> Gen.scopedExp)
      renumbered (renumbered e) === renumbered e

    prop 300 "preserves well-scopedness and binder uniqueness" do
      e ← forAll (freshened <$> Gen.scopedExp)
      let renumberedModule = renumberUberModule (inAllSites e)
      lintWellScoped renumberedModule === []
      lintUniqueBinders renumberedModule === []

--------------------------------------------------------------------------------
-- Fixtures --------------------------------------------------------------------

{- | A name as the IR passes mint them: @base$N@, with @N@ drawn from the
pipeline-global supply. The offset added to every index in a fixture
stands for supply consumed earlier by unrelated code.
-}
minted ∷ Text → Natural → Name
minted base k = Name (base <> "$" <> show k)

{- | @let v$k = 1; f$(k+1) = \\x$(k+2) → x$(k+2) in f$(k+1) v$k@ — three
suffix-minted binders.
-}
letWithMintedLocals ∷ Natural → Exp
letWithMintedLocals k =
  lets
    ( Standalone (noAnn, minted "v" k, literalInt 1)
        :| [ Standalone
               ( noAnn
               , minted "f" (k + 1)
               , abstraction
                   (paramNamed (minted "x" (k + 2)))
                   (refLocal (minted "x" (k + 2)))
               )
           ]
    )
    (application (refLocal (minted "f" (k + 1))) (refLocal (minted "v" k)))

{- | The prefix-minted counterpart: CSE's @$cseN@ shared binding holding
the continuation helper @$kontN@ that deep-bind flattening lifts out.
-}
letWithMintedTags ∷ Natural → Exp
letWithMintedTags k =
  lets
    ( Standalone
        ( noAnn
        , Name ("$kont" <> show k)
        , abstraction
            (paramNamed (minted "n" (k + 1)))
            (refLocal (minted "n" (k + 1)))
        )
        :| [ Standalone
               ( noAnn
               , Name ("$cse" <> show (k + 2))
               , refLocal (Name ("$kont" <> show k))
               )
           ]
    )
    (refLocal (Name ("$cse" <> show (k + 2))))

-- | One minted binder — a site consuming less supply than the others.
soleMintedLocal ∷ Natural → Exp
soleMintedLocal k =
  boundTo ("v$" <> show k) (literalInt 1) (refLocal (minted "v" k))

twoSites ∷ [(Name, Exp)]
twoSites = [(Name "first", letWithMintedLocals 0), (Name "second", secondSite)]

-- | The site whose renumbering must not move when its neighbour changes.
secondSite ∷ Exp
secondSite = letWithMintedLocals 700

twoSiteModule ∷ UberModule
twoSiteModule = emptyUberModule {uberModuleExports = twoSites}

inAllSites ∷ Exp → UberModule
inAllSites e =
  UberModule
    { uberModuleBindings = [Standalone (qname, e)]
    , uberModuleForeigns = [(qname, e)]
    , uberModuleExports = [(Name "it", e)]
    }
 where
  qname = QName (moduleNameFromString "Main") (Name "it")

--------------------------------------------------------------------------------
-- Helper Functions ------------------------------------------------------------

renumbered ∷ HasCallStack ⇒ Exp → Exp
renumbered = applyPassToExpression "renumberUberModule" renumberUberModule

unchanged ∷ HasCallStack ⇒ Exp → IO ()
unchanged e = renumbered e `shouldBe` e

boundTo ∷ Text → Exp → Exp → Exp
boundTo name rhs = lets (Standalone (noAnn, Name name, rhs) :| [])

{- | The second of two sites, renumbered with the first replaced by the
given site — the same site, following neighbours of different sizes.
-}
secondSiteAfter ∷ Exp → Maybe Exp
secondSiteAfter firstSite =
  List.lookup (Name "second") . uberModuleExports . renumberUberModule $
    emptyUberModule
      { uberModuleExports =
          [(Name "first", firstSite), (Name "second", secondSite)]
      }

{- | Rename every binder to a supply-minted name, as an inline paste
does. Freshening requires the unique binders the entry pass establishes,
so the site is uniquified first, exactly as the pipeline orders them.
-}
freshened ∷ Exp → Exp
freshened = runSupply . freshenBinders . uniquifyNamesInExpr

-- | Consume the given number of fresh names, as earlier passes do.
burn ∷ Natural → SupplyM ()
burn k = replicateM_ (fromIntegral k) (freshName "burn$")
