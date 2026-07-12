module Language.PureScript.Backend.IR.Inliner where

import Data.Char (isAlphaNum, isUpper)
import Data.Map qualified as Map
import Data.Text qualified as Text
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name
  , PropName (..)
  , moduleNameFromString
  , nameParser
  , nameToText
  , runModuleName
  )
import Text.Megaparsec qualified as Megaparsec
import Text.Megaparsec.Char qualified as MC
import Text.Megaparsec.Char.Lexer qualified as ML

{- Note [Inline annotations and inlining heuristics]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
An @\@inline <name> always@ / @\@inline <name> never@ pragma in a module comment
travels to the optimizer's inlining decision through several stages:

  1. 'pragmaParser' parses one pragma comment into a 'Pragma' (the bound 'Name'
     and an 'Annotation').
  2. 'Language.PureScript.Backend.IR.parseAnnotations' collects them into a
     @Map Name Annotation@ in the translation context, and 'useAnnotation'
     moves each into the annotated binding's 'Ann' as the binding is
     translated (see Note [Inliner annotations must all be consumed]).
  3. From there the 'Annotation' rides along as the expression's @ann@.
  4. The optimizer reads it back: @Just Always@ (via
     'Language.PureScript.Backend.IR.Optimizer.isInlinableExpr') forces
     inlining. For @Just Never@, 'optimizedUberModule' collects the annotated
     binding names once up front (so the veto survives later rewrites that drop
     the annotation off a binding's root) and refuses to inline them. @Nothing@
     leaves the ref / small-literal / single-use heuristic to decide.

A pragma on a foreign name is drained into 'moduleForeigns' and reaches the
linker, which binds each foreign name to an 'ObjectProp' accessor annotated
with that pragma, defaulting to 'Inline.Always' so the wrapper around the FFI
object is inlined away unless a pragma says otherwise (see
Note [Foreign bindings structure emitted by the Linker]). @never@ keeps the
accessor as a shared binding — the way to declare sharing intent for an FFI
value.

The 'ForeignImport' expression itself — the table of a foreign module's
exports — is the one shape the optimizer refuses to inline even when it is
referenced exactly once. Its export values are opaque to the IR, and some of
them are Lua table constructors with identity (e.g. @unit = {}@ in the
prelude), so pasting the import into its use site — possibly under a lambda —
would re-evaluate the foreign source per call and allocate fresh tables where
every site is supposed to share one. The table stays hoisted as a single
binding and the always-inlined 'ObjectProp' wrappers turn into field reads
off it.
-}

--------------------------------------------------------------------------------
-- Directive language ----------------------------------------------------------

-- | An inlining policy that rides on an expression's 'Ann' slot.
data Annotation = Always | Never | Arity Natural
  deriving stock (Show, Eq, Ord)

{- | A parsed directive mode. 'ModeDefault' (the written @default@) resolves
to no annotation — it exists so a higher-precedence source can mask a
lower-precedence directive back to the built-in heuristics; it never rides
on an 'Ann' slot.
-}
data Mode = ModeDefault | ModeAnnotation Annotation
  deriving stock (Show, Eq, Ord)

{- | The accessor part of a directive target: @.label@ names a field of a
dictionary record binding, @...label@ names a field projected out of the
result of applying the binding (@f(x).label@).
-}
data Accessor = Field PropName | AppliedField PropName
  deriving stock (Show, Eq, Ord)

-- | Render an accessor the way directives spell it.
printAccessor ∷ Accessor → Text
printAccessor = \case
  Field label → "." <> renderPropName label
  AppliedField label → "..." <> renderPropName label

-- | What a directive applies to: a binding, or a field selected out of it.
type Target = (Name, Maybe Accessor)

{- | Precedence tier of a module-header pragma: a plain (local) directive
beats the project directives file, which beats an @export@-scoped directive.
-}
data Scope = LocalScope | ExportScope
  deriving stock (Show, Eq, Ord)

-- | One parsed @\@inline@ module-header pragma.
data Pragma = Pragma
  { pragmaScope ∷ Scope
  , pragmaTarget ∷ Target
  , pragmaMode ∷ Mode
  }
  deriving stock (Show, Eq, Ord)

-- | The parsed contents of a @--directives@ file, grouped by module.
type Directives = Map ModuleName (Map Target Mode)

{- | Resolve the three explicit directive sources for a module's targets into
the annotations to attach, layered by precedence: a local module-header
directive beats the project directives file, which beats an @export@-scoped
header directive. A winning 'ModeDefault' still occupies its key — masking
the lower tiers — and attaches 'Nothing' (the built-in heuristics).
-}
resolveModes
  ∷ Map Target Mode
  -- ^ module-header pragmas, local scope (highest precedence)
  → Map Target Mode
  -- ^ the @--directives@ file slice for this module
  → Map Target Mode
  -- ^ module-header pragmas, export scope (lowest explicit tier)
  → Map Target (Maybe Annotation)
resolveModes localModes fileModes exportModes =
  Map.unions [localModes, fileModes, exportModes] <&> \case
    ModeDefault → Nothing
    ModeAnnotation ann → Just ann

--------------------------------------------------------------------------------
-- Parsers ----------------------------------------------------------------------

type Parser = Megaparsec.Parsec Void Text

pragmaParser ∷ Parser Pragma
pragmaParser = do
  symbol "@inline"
  -- @export@ is itself a valid binding name: when no target and mode
  -- follow the word, backtrack and read it as the target instead.
  Megaparsec.try (directiveParser ExportScope (symbol "export"))
    <|> directiveParser LocalScope pass

directiveParser ∷ Scope → Parser () → Parser Pragma
directiveParser scope prefix = do
  prefix
  pragmaTarget ← targetParser
  pragmaMode ← modeParser
  pure Pragma {pragmaScope = scope, pragmaTarget, pragmaMode}

targetParser ∷ Parser Target
targetParser = do
  name ← nameParser
  accessor ← optional accessorParser
  sc
  pure (name, accessor)

accessorParser ∷ Parser Accessor
accessorParser =
  (AppliedField <$> (Megaparsec.chunk "..." *> propNameParser))
    <|> (Field <$> (MC.char '.' *> propNameParser))
 where
  propNameParser = PropName . nameToText <$> nameParser

modeParser ∷ Parser Mode
modeParser =
  (ModeDefault <$ symbol "default")
    <|> (ModeAnnotation <$> annotationParser)

annotationParser ∷ Parser Annotation
annotationParser =
  (Always <$ symbol "always")
    <|> (Never <$ symbol "never")
    <|> (Arity <$> arityParser)

arityParser ∷ Parser Natural
arityParser = do
  symbol "arity"
  symbol "="
  arity ← ML.lexeme sc ML.decimal
  when (arity == 0) $ fail "arity must be at least 1"
  pure arity

{- | The contents of a @--directives@ file: one directive per line in the
module-header pragma syntax, except that the target is fully qualified
(@Some.Module.binding@) and no scope prefix is accepted — the file is
already a global source. Blank lines and @--@ line comments are allowed.
Naming the same target twice is an error.
-}
directivesFileParser ∷ Parser Directives
directivesFileParser = do
  scn
  entries ← Megaparsec.many (entryParser <* scn)
  foldlM insertEntry Map.empty entries
 where
  entryParser ∷ Parser (ModuleName, Target, Mode)
  entryParser = do
    modname ← qualifierParser
    (target, mode) ← (,) <$> targetParser <*> modeParser
    pure (modname, target, mode)

  insertEntry
    ∷ Directives → (ModuleName, Target, Mode) → Parser Directives
  insertEntry directives (modname, target@(name, accessor), mode) = do
    let known = Map.findWithDefault Map.empty modname directives
    when (Map.member target known) do
      fail . toString $
        "duplicate directive for "
          <> runModuleName modname
          <> "."
          <> nameToText name
          <> maybe "" printAccessor accessor
    pure $ Map.insert modname (Map.insert target mode known) directives

  -- Vertical space and @--@ line comments between directives.
  scn ∷ Parser ()
  scn = ML.space MC.space1 (ML.skipLineComment "--") empty

{- | The dotted module prefix of a fully-qualified target: one or more
uppercase-led, dot-terminated segments. The lowercase-led segment after
them is the binding name and is left unconsumed.
-}
qualifierParser ∷ Parser ModuleName
qualifierParser = do
  segments ← Megaparsec.some (Megaparsec.try segmentParser)
  pure . moduleNameFromString $ Text.intercalate "." segments
 where
  segmentParser ∷ Parser Text
  segmentParser = do
    initial ← Megaparsec.satisfy isUpper
    rest ← Megaparsec.takeWhileP (Just "module name char") isAlphaNum
    void $ MC.char '.'
    pure $ Text.cons initial rest

symbol ∷ Text → Parser ()
symbol = void . ML.symbol sc

sc ∷ Parser ()
sc = ML.space (MC.hspace1 @_ @Text) empty empty
