module Language.PureScript.Backend.Lua.Linker.Foreign
  ( Source (..)
  , Parser
  , parseForeignSource
  , Error (..)

    -- * Internal
  , moduleParser
  , valueParser
  ) where

import Control.Monad.Combinators.NonEmpty qualified as NE
import Control.Monad.Trans.Except (except, throwE)
import Data.Char qualified as Char
import Data.DList (DList)
import Data.DList qualified as DL
import Data.String qualified as String
import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Key (Key)
import Language.PureScript.Backend.Lua.Key qualified as Key
import Language.PureScript.Backend.Lua.Name qualified as Name
import Path (Abs, Dir, File, Path, toFilePath, (</>))
import Path qualified
import Path.IO qualified as Path
import Text.Megaparsec (Parsec)
import Text.Megaparsec qualified as MP
import Text.Megaparsec qualified as Megaparsec
import Text.Megaparsec.Char qualified as MP
import Text.Show (Show (..))
import Prelude hiding (show)

data Source = Source {header ∷ Maybe Text, exports ∷ NonEmpty (Key, Text)}
  deriving stock (Eq, Show)

{- | Parse a foreign source file which has to be in the following format:
@@
  <header>
  return {
    identifier = (<value>),
    ...
    identifier = (<value>)
  }
@@

The <header> is optional and can contain any Lua statements except 'return'.
It is meant to host Lua code shared by all the export <values>.

The <value> is a Lua expression. The braces around a <value> are required.
-}
parseForeignSource ∷ Path Abs Dir → FilePath → IO (Either Error Source)
parseForeignSource foreigns path = runExceptT do
  filePath ← toFilePath <$> resolveForModule path foreigns
  src ← Text.strip . decodeUtf8 <$> liftIO (readFileBS filePath)
  let (headerLines, returnStat) = break isReturn (Text.lines src)
  case Megaparsec.parse moduleParser filePath (unlines returnStat) of
    Left err → throwE $ ForeignErrorParse filePath err
    Right parsed → do
      let header = guarded (not . Text.null) (Text.strip (unlines headerLines))
      pure $ Source header (fmap fixDataIntToStringAsGlobalLeak parsed)
 where
  isReturn ∷ Text → Bool
  isReturn = Text.isPrefixOf "return"

  resolveForModule ∷ FilePath → Path Abs Dir → ExceptT Error IO (Path Abs File)
  resolveForModule modulePath foreignBaseDir = do
    cwd ← Path.getCurrentDir
    absModulePath ←
      Path.parseAbsFile modulePath
        & maybe (Path.resolveFile cwd modulePath) pure
    -- Its not always true that module path is relative to the cwd
    let relModulePath = Path.makeRelative @_ @Maybe cwd absModulePath
    foreignFile ← Path.filename <$> Path.replaceExtension ".lua" absModulePath
    let searchLocations =
          Path.parent absModulePath :| case relModulePath of
            Nothing → []
            Just mp → [foreignBaseDir </> Path.parent mp]
    filesToSearch ← forM searchLocations $ \location →
      Path.resolveFile location (toFilePath foreignFile)
    found ← forM filesToSearch \file →
      bool Nothing (Just file) <$> Path.doesFileExist file
    except $
      maybeToRight (ForeignFileNotFound modulePath filesToSearch) (asum found)

--------------------------------------------------------------------------------
-- Parser ----------------------------------------------------------------------

type Parser = Parsec Void Text

moduleParser ∷ Parser (NonEmpty (Key, Text))
moduleParser = do
  MP.string "return" *> MP.space1
  char '{'
  exports ← NE.sepEndBy1 foreignExport (char ',')
  char '}'
  pure exports

foreignExport ∷ Parser (Key, Text)
foreignExport = do
  exportKey ← Key.parser
  char '='
  exportValue ← valueParser
  pure (exportKey, toText exportValue)

valueParser ∷ Parser String
valueParser = char '(' *> go 0 DL.empty <* MP.space
 where
  go ∷ Int → DList Char → Parser String
  go numToClose value = do
    cs ← many $ MP.satisfy (\c → c /= '(' && c /= ')')
    MP.optional MP.anySingle >>= \case
      Just '(' → go (succ numToClose) (DL.snoc (value <> DL.fromList cs) '(')
      Just ')' →
        if numToClose > 0
          then go (pred numToClose) (DL.snoc (value <> DL.fromList cs) ')')
          else pure $ DL.toList $ value <> DL.fromList cs
      _ → pure $ DL.toList (value <> DL.fromList cs)

char ∷ Char → Parser ()
char c = MP.char c *> MP.space

fixDataIntToStringAsGlobalLeak ∷ (Key, Text) → (Key, Text)
fixDataIntToStringAsGlobalLeak (key, value)
  | Key.toSafeName key == Name.unsafeName "toStringAs"
  , hasKnownContext linesOfValue =
      (key, Text.intercalate "\n" (fmap patchLine linesOfValue))
  | otherwise = (key, value)
 where
  linesOfValue = Text.lines value

  hasKnownContext ls =
    any (("math.floor" `Text.isInfixOf`) . normalizeSpaces) ls
      && any (("table.insert" `Text.isInfixOf`) . normalizeSpaces) ls
      && any hasReturnFunctionArg ls

  hasReturnFunctionArg line =
    let compact = normalizeSpaces line
     in "return" `Text.isPrefixOf` compact
          && "function(i)" `Text.isSuffixOf` compact

  patchLine line
    | Just indent <- parseFloorAssignment line =
        indent <> "local n = floor(i)"
    | otherwise = line

  parseFloorAssignment line = do
    let indent = Text.takeWhile Char.isSpace line
        stripped = Text.strip line
    guard (not ("local " `Text.isPrefixOf` stripped))
    (lhs, rhsWithEq) <- Just (Text.breakOn "=" stripped)
    guard (not (Text.null rhsWithEq))
    guard (Text.strip lhs == "n")
    let rhs = Text.strip (Text.drop 1 rhsWithEq)
    guard (rhs == "floor(i)")
    pure indent

  normalizeSpaces = Text.filter (not . Char.isSpace)

--------------------------------------------------------------------------------
-- Errors ----------------------------------------------------------------------

data Error
  = ForeignFileNotFound FilePath (NonEmpty (Path Abs File))
  | ForeignErrorParse FilePath (Megaparsec.ParseErrorBundle Text Void)
  deriving stock (Eq)

instance Show Error where
  show (ForeignFileNotFound modulePath searched) =
    "Foreign file for the module "
      <> show modulePath
      <> " not found in the following locations:\n"
      <> String.unlines (toList searched <&> ("-  " <>) . toFilePath)
  show (ForeignErrorParse filePath err) =
    "Error parsing foreign file "
      <> show filePath
      <> ":\n"
      <> Megaparsec.errorBundlePretty err
