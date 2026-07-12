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
An inlining directive names a target and a mode:

  @\@inline [export] name accessor? mode@   (module-header pragma)
  @Some.Module.name accessor? mode@         (a @--directives@ file line)

  accessor ::= ".label" | "...label"
  mode     ::= default | never | always | arity=N   (N > 0)

The bare target names a whole binding. @.label@ names one field of a
dictionary-record binding, @...label@ one field of the record a binding
returns when applied (@f(x).label@) — a policy for one method instead of
the whole record. Directives come from three explicit sources, layered by
specificity (most specific wins, per target):

  1. a local module-header pragma (no @export@) in the defining module;
  2. the project-wide @--directives@ file;
  3. an @\@inline export@ module-header pragma — a default the library
     author ships with the module, overridable by the consumer's file.

'resolveModes' performs exactly this layering; a winning @default@ still
masks the lower tiers and resolves to no annotation — the built-in
heuristics. Module-header pragmas name own-module bindings only and are
validated strictly (a target matching nothing is an error); file entries
are fully qualified and best-effort (a shared file may cover modules
absent from the build). In a whole-program optimizer @export@ needs no
transitivity machinery: the resolved annotation rides the binding into
the uber-module, so it is simply the weakest explicit tier.

The resolved winner travels to the optimizer's decision through several
stages:

  1. 'pragmaParser' / 'directivesFileParser' parse the sources;
     'Language.PureScript.Backend.IR.parseAnnotations' collects the
     header pragmas by scope, and 'Language.PureScript.Backend.IR.mkModule'
     resolves them against the file slice into a
     @Map Target (Maybe Annotation)@ in the translation context.
  2. 'Language.PureScript.Backend.IR.useAnnotation' moves a whole-binding
     winner into the binding root's 'Ann' as the binding is translated;
     an accessor winner is stamped on the ann slot of the object-literal
     field it selects (see Note [Inliner annotations must all be consumed]).
  3. From there the 'Annotation' rides along as the expression's @ann@.
  4. 'Language.PureScript.Backend.IR.Optimizer.collectInlinePolicy' reads
     every annotation back once, from the pristine uber-module — later
     rewrites may strip an annotation off its node, so decisions key off
     names — and the optimizer consults the resulting policy:

       * @Just Always@ on a root forces inlining: the top-level inliner
         consults it by name (@policyAlways@) and keeps a bare-Ref alias
         to such a name as the single materialization point — dissolving
         the alias would multiply the target's use sites right before
         Always pastes its body into each (issue #171). The pasted
         copies shed the annotation at the paste, so only pristine roots
         ever carry directive weight; the local rules still read the
         root annotation directly ('isInlinableExpr');
       * @Never@ names are never pasted ('withBinding', the call-site
         rules, and the uncurry split all veto them);
       * @Arity n@ names are pasted exactly at call sites applying at
         least n arguments ('inlineSaturatedCall'), bypassing the size
         budget, and are vetoed everywhere else;
       * field policies gate the projection rules
         ('resolveDictionaryProp', 'inlineAnnotatedProjection').

A whole-binding pragma on a foreign name (@always@/@never@/@default@ only —
there is no body to paste at an arity, nor a field to select) is drained
into 'moduleForeigns' and reaches the linker, which binds each foreign name
to an 'ObjectProp' accessor carrying that pragma alone (see
Note [Foreign bindings structure emitted by the Linker]). An unannotated
accessor dissolves into its use sites like any cheap projection, but the
sharing is rebuilt at the end of the pipeline:
'Language.PureScript.Backend.IR.Optimizer.shareForeignAccessors' re-binds a
field read that survived at two or more sites, since a read repeated per
site loses to a shared binding once stage-2 promotion turns that binding
into a chunk local (issue #248). @always@ opts a name out of the re-binding
— a per-site field read at any use count — and @never@ keeps the accessor a
shared binding from the start, even when used once; an explicit @default@
resolves to no annotation, same as leaving the pragma off. The lifted
foreign bodies are the exception:
'Language.PureScript.Backend.Lua.ForeignLift.liftForeigns' marks them
@always@ itself, because they exist to beta-reduce at saturated call sites.

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
