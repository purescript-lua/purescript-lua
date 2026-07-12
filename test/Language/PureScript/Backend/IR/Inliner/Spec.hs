module Language.PureScript.Backend.IR.Inliner.Spec where

import Data.Map qualified as Map
import Hedgehog (MonadTest, failure, footnote, (===))
import Language.PureScript.Backend.IR.Inliner
  ( Accessor (AppliedField, Field)
  , Annotation (Always, Arity, Never)
  , Directives
  , Mode (ModeAnnotation, ModeDefault)
  , Pragma (Pragma)
  , Scope (ExportScope, LocalScope)
  )
import Language.PureScript.Backend.IR.Inliner qualified as Inliner
import Language.PureScript.Backend.IR.Names
  ( Name (..)
  , PropName (..)
  , moduleNameFromString
  )
import Test.Hspec (Spec, describe)
import Test.Hspec.Hedgehog.Extended (test)
import Text.Megaparsec qualified as Megaparsec

spec ∷ Spec
spec = describe "IR Inliner" do
  describe "parses pragmas" do
    test "@inline foo always" do
      pragma ← parsePragma "@inline foo always "
      pragma === Pragma LocalScope (Name "foo", Nothing) (ModeAnnotation Always)
    test "@inline foo never" do
      pragma ← parsePragma "@inline foo never "
      pragma === Pragma LocalScope (Name "foo", Nothing) (ModeAnnotation Never)
    test "@inline foo default" do
      pragma ← parsePragma "@inline foo default"
      pragma === Pragma LocalScope (Name "foo", Nothing) ModeDefault
    test "@inline foo arity=2" do
      pragma ← parsePragma "@inline foo arity=2"
      pragma
        === Pragma LocalScope (Name "foo", Nothing) (ModeAnnotation (Arity 2))
    test "rejects arity=0" do
      rejectPragma "@inline foo arity=0"
    test "@inline export foo arity=1" do
      pragma ← parsePragma "@inline export foo arity=1"
      pragma
        === Pragma ExportScope (Name "foo", Nothing) (ModeAnnotation (Arity 1))
    test "@inline export always names a binding called export" do
      pragma ← parsePragma "@inline export always"
      pragma
        === Pragma LocalScope (Name "export", Nothing) (ModeAnnotation Always)
    test "@inline foo.bind never" do
      pragma ← parsePragma "@inline foo.bind never"
      pragma
        === Pragma
          LocalScope
          (Name "foo", Just (Field (PropName "bind")))
          (ModeAnnotation Never)
    test "@inline foo...dimap always" do
      pragma ← parsePragma "@inline foo...dimap always"
      pragma
        === Pragma
          LocalScope
          (Name "foo", Just (AppliedField (PropName "dimap")))
          (ModeAnnotation Always)
    test "@inline export foo.bind default" do
      pragma ← parsePragma "@inline export foo.bind default"
      pragma
        === Pragma
          ExportScope
          (Name "foo", Just (Field (PropName "bind")))
          ModeDefault

  describe "parses a directives file" do
    test "directives with comments and blank lines" do
      directives ←
        parseDirectives . unlines $
          [ "-- inline policy for the lens stack"
          , ""
          , "Data.Lens.over arity=2"
          , "Data.Lens.view always"
          , "Data.Profunctor.profunctorFn.dimap never"
          , "Data.Functor.functorArray...map default"
          ]
      directives
        === Map.fromList
          [
            ( moduleNameFromString "Data.Lens"
            , Map.fromList
                [ ((Name "over", Nothing), ModeAnnotation (Arity 2))
                , ((Name "view", Nothing), ModeAnnotation Always)
                ]
            )
          ,
            ( moduleNameFromString "Data.Profunctor"
            , Map.fromList
                [
                  ( (Name "profunctorFn", Just (Field (PropName "dimap")))
                  , ModeAnnotation Never
                  )
                ]
            )
          ,
            ( moduleNameFromString "Data.Functor"
            , Map.fromList
                [
                  ( (Name "functorArray", Just (AppliedField (PropName "map")))
                  , ModeDefault
                  )
                ]
            )
          ]
    test "rejects an unqualified target" do
      rejectDirectives "over always\n"
    test "rejects export scope" do
      rejectDirectives "export Data.Lens.over always\n"
    test "rejects duplicate targets" do
      rejectDirectives "Data.Lens.over always\nData.Lens.over never\n"

  describe "resolves directive precedence" do
    test "a local directive beats the directives file" do
      Inliner.resolveModes
        (one (target, ModeAnnotation Never))
        (one (target, ModeAnnotation Always))
        mempty
        === one (target, Just Never)
    test "the directives file beats an exported directive" do
      Inliner.resolveModes
        mempty
        (one (target, ModeAnnotation Never))
        (one (target, ModeAnnotation Always))
        === one (target, Just Never)
    test "an exported directive beats the built-in heuristics" do
      Inliner.resolveModes
        mempty
        mempty
        (one (target, ModeAnnotation (Arity 3)))
        === one (target, Just (Arity 3))
    test "an explicit default masks lower tiers" do
      Inliner.resolveModes
        (one (target, ModeDefault))
        (one (target, ModeAnnotation Never))
        mempty
        === one (target, Nothing)
    test "disjoint targets union across sources" do
      let other = (Name "bar", Nothing) ∷ Inliner.Target
      Inliner.resolveModes
        (one (target, ModeAnnotation Always))
        mempty
        (one (other, ModeAnnotation Never))
        === Map.fromList [(target, Just Always), (other, Just Never)]

--------------------------------------------------------------------------------
-- Helpers ---------------------------------------------------------------------

target ∷ Inliner.Target
target = (Name "foo", Nothing)

parsePragma ∷ MonadTest m ⇒ Text → m Pragma
parsePragma = parseWith Inliner.pragmaParser

parseDirectives ∷ MonadTest m ⇒ Text → m Directives
parseDirectives = parseWith Inliner.directivesFileParser

rejectPragma ∷ MonadTest m ⇒ Text → m ()
rejectPragma = rejectWith Inliner.pragmaParser

rejectDirectives ∷ MonadTest m ⇒ Text → m ()
rejectDirectives = rejectWith Inliner.directivesFileParser

parseWith ∷ MonadTest m ⇒ Inliner.Parser a → Text → m a
parseWith parser src =
  case Megaparsec.parse (parser <* Megaparsec.eof) "<test>" src of
    Left eb → do
      footnote $ Megaparsec.errorBundlePretty eb
      failure
    Right a → pure a

rejectWith ∷ (MonadTest m, Show a) ⇒ Inliner.Parser a → Text → m ()
rejectWith parser src =
  case Megaparsec.parse (parser <* Megaparsec.eof) "<test>" src of
    Left _ → pass
    Right a → do
      footnote $ "unexpectedly parsed: " <> show a
      failure
