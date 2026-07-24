module Language.PureScript.Backend.Lua.Linker.Foreign
  ( Source (..)
  , parseForeignSource
  , interpretForeignModule
  , Error (..)

    -- * Shared with "Language.PureScript.Backend.Lua.Optimizer"
  , chunkScopeUsesVararg
  ) where

import Control.Monad.Trans.Except (except)
import Data.Set qualified as Set
import Data.String qualified as String
import Language.PureScript.Backend.Lua.Key (Key (..))
import Language.PureScript.Backend.Lua.Name qualified as Name
import Language.PureScript.Backend.Lua.Parser qualified as Parser
import Language.PureScript.Backend.Lua.Types
  ( Annotated
  , Comments
  , ExpF (..)
  , StatementF (..)
  , TableRowF (..)
  , VarF (..)
  )
import Path (Abs, Dir, File, Path, toFilePath, (</>))
import Path qualified
import Path.IO qualified as Path
import Text.Show (Show (..))
import Prelude hiding (show)

{- Note [Foreign module source format]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
An FFI file is an ordinary Lua 5.1 module: any statements (the shared
header), closed by @return { name = <value>, ... }@. It is parsed with the
full Lua parser (see Note [Parsing foreign Lua sources] in
'Language.PureScript.Backend.Lua.Parser'), so a syntax error anywhere in the
file is a compile-time error, and export values land in the Lua AST where
the optimizer can see into them.

'interpretForeignModule' imposes the module shape on the parsed chunk:

  * The chunk's last statement must be a @return@ of exactly one table
    constructor. The Lua grammar permits @return@ only as the final statement
    of a block, so a well-formed file cannot hide an early top-level return
    inside the header.
  * Every row of that table must be keyed by a plain identifier
    (@name = <value>@) or by a bracketed string literal (@["if"] = <value>@)
    — the latter is how an export named after a Lua keyword appears; see
    Note [Lua reserved words as foreign export keys] in
    'Language.PureScript.Backend.Lua.Key'.

  * The chunk's top-level scope must not use @...@ ('chunkScopeUsesVararg').
    The parser accepts it — a main chunk is a vararg function in Lua — but
    the file is embedded into a function scope in the generated output
    (a header becomes an IIFE body, export values land in expression
    positions), where chunk varargs are either a syntax error or silently
    rebound. @...@ inside the file's own vararg functions is unaffected.

The result is a 'Source': header statements, per-export annotated
expressions (a comment written above an export sticks with its value), and
the comments that preceded the @return@ itself (e.g. a module-level
commentary in a file with no header statements).
'Language.PureScript.Backend.Lua' consumes it when lowering
'Language.PureScript.Backend.IR.ForeignImport'.
-}

data Source = Source
  { header ∷ [Annotated Comments StatementF]
  -- ^ statements preceding the final @return@
  , returnComments ∷ Comments
  -- ^ comments attached to the @return@ statement and its table
  , exports ∷ NonEmpty (Key, Annotated Comments ExpF)
  -- ^ export values in source order
  }
  deriving stock (Eq, Show)

{- | Locate, read, parse, and interpret the FFI file for a module.
See Note [Foreign module source format].
-}
parseForeignSource ∷ Path Abs Dir → FilePath → IO (Either Error Source)
parseForeignSource foreigns path = runExceptT do
  filePath ← toFilePath <$> resolveForModule path foreigns
  src ← decodeUtf8 <$> liftIO (readFileBS filePath)
  statements ←
    except . first (ForeignErrorParse filePath) $
      Parser.parseChunk filePath src
  except $ interpretForeignModule filePath statements
 where
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

{- | Impose the foreign-module shape on a parsed chunk.
See Note [Foreign module source format].
-}
interpretForeignModule
  ∷ FilePath
  → [Annotated Comments StatementF]
  → Either Error Source
interpretForeignModule filePath statements = do
  when (chunkScopeUsesVararg statements) $
    Left (ForeignChunkVararg filePath)
  case reverse statements of
    (retComments, Return [(tableComments, TableCtor rows)]) : reversedHeader → do
      exports ←
        maybeToRight (ForeignNoExports filePath) . nonEmpty
          =<< traverse rowToExport rows
      pure
        Source
          { header = reverse reversedHeader
          , returnComments = retComments <> tableComments
          , exports
          }
    _ → Left (ForeignNoExportsReturn filePath)
 where
  rowToExport
    ∷ Annotated Comments TableRowF
    → Either Error (Key, Annotated Comments ExpF)
  rowToExport (rowComments, row) = case row of
    TableRowNV name (valueComments, value) →
      Right (KeyName name, (rowComments <> valueComments, value))
    TableRowKV (_, String key) (valueComments, value)
      -- See Note [Lua reserved words as foreign export keys]
      | key `Set.member` Name.reserved →
          Right (KeyReserved key, (rowComments <> valueComments, value))
      | Just name ← Name.fromText key →
          Right (KeyName name, (rowComments <> valueComments, value))
    _ → Left (ForeignUnsupportedExportKey filePath)

{- | Whether @...@ occurs in the chunk's own top-level scope: reachable from
a statement or expression without entering a nested function, whose varargs
are its own. Top-level @...@ is legal Lua (the main chunk is vararg) and the
parser accepts it, but an FFI file is embedded into a function scope in the
generated output, where chunk varargs cannot mean anything — so the foreign
/shape/ rejects it (see Note [Foreign module source format]).
-}
chunkScopeUsesVararg ∷ [Annotated Comments StatementF] → Bool
chunkScopeUsesVararg = any statUses
 where
  statUses ∷ Annotated Comments StatementF → Bool
  statUses (_, stat) = case stat of
    Assign vars vals →
      any varUses (toList vars) || any expUses (toList vals)
    Local _names vals → any expUses vals
    IfThenElse p thenBlock elseBlock →
      expUses p || any statUses thenBlock || any statUses elseBlock
    Return es → any expUses es
    CallStatement e → expUses e
    Do body → any statUses body
    While p body → expUses p || any statUses body
    Repeat body p → any statUses body || expUses p
    ForNum _name start limit step body →
      expUses start
        || expUses limit
        || any expUses step
        || any statUses body
    ForIn _names es body → any expUses (toList es) || any statUses body
    -- A (local) function's body is its own vararg scope.
    LocalFunction {} → False
    Break → False

  expUses ∷ Annotated Comments ExpF → Bool
  expUses (_, e) = case e of
    Vararg → True
    Nil → False
    Boolean _ → False
    Integer _ → False
    Float _ → False
    String _ → False
    Function _params _body → False
    TableCtor rows → any rowUses rows
    UnOp _op a → expUses a
    BinOp _op l r → expUses l || expUses r
    Var v → varUses v
    FunctionCall f args → expUses f || any expUses args
    MethodCall o _name args → expUses o || any expUses args
    Paren a → expUses a

  varUses ∷ Annotated Comments VarF → Bool
  varUses (_, v) = case v of
    VarName _ → False
    VarIndex e i → expUses e || expUses i
    VarField e _name → expUses e

  rowUses ∷ Annotated Comments TableRowF → Bool
  rowUses (_, r) = case r of
    TableRowKV k v → expUses k || expUses v
    TableRowNV _name v → expUses v
    TableRowV v → expUses v

--------------------------------------------------------------------------------
-- Errors ----------------------------------------------------------------------

data Error
  = ForeignFileNotFound FilePath (NonEmpty (Path Abs File))
  | ForeignErrorParse FilePath Parser.ParseError
  | ForeignNoExportsReturn FilePath
  | ForeignNoExports FilePath
  | ForeignUnsupportedExportKey FilePath
  | ForeignChunkVararg FilePath
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
      <> Parser.renderParseError err
  show (ForeignNoExportsReturn filePath) =
    "Foreign file "
      <> show filePath
      <> " must end in `return { ... }` with a table of exports."
  show (ForeignNoExports filePath) =
    "Foreign file " <> show filePath <> " exports an empty table."
  show (ForeignUnsupportedExportKey filePath) =
    "Foreign file "
      <> show filePath
      <> " has an export with an unsupported key; every export must be\n"
      <> "keyed by an identifier (name = ...) or a quoted Lua keyword\n"
      <> "([\"if\"] = ...)."
  show (ForeignChunkVararg filePath) =
    "Foreign file "
      <> show filePath
      <> " uses '...' in its top-level scope. The file is embedded into a\n"
      <> "function scope in the generated output, so chunk varargs (e.g. the\n"
      <> "`local name = ...` module-name idiom) cannot mean anything there;\n"
      <> "'...' works only inside the file's own vararg functions."
