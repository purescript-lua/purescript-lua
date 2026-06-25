module Language.PureScript.Backend.IR.Inliner where

import Language.PureScript.Backend.IR.Names (Name, nameParser)
import Text.Megaparsec qualified as Megaparsec
import Text.Megaparsec.Char qualified as MC
import Text.Megaparsec.Char.Lexer qualified as ML

type Pragma = (Name, Annotation)

{- Note [Inline annotations and inlining heuristics]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
An @\@inline always@ / @\@inline never@ pragma in a module comment travels to
the optimizer's inlining decision through several stages:

  1. 'pragmaParser' parses one pragma comment into a 'Pragma' (a 'Name' and an
     'Annotation').
  2. 'Language.PureScript.Backend.IR.parseAnnotations' collects them into a
     @Map Name Annotation@ in the translation context, and 'useAnnotation'
     moves each into the annotated binding's 'Ann' as the binding is
     translated (see Note [Inliner annotations must all be consumed]).
  3. From there the 'Annotation' rides along as the expression's @ann@.
  4. 'Language.PureScript.Backend.IR.Optimizer.isInlinableExpr' reads it back
     with 'getAnn': @Just Always@ forces inlining, @Just Never@ blocks it, and
     @Nothing@ leaves the heuristic (a ref, a small literal, or a single-use
     binding) to decide.

The linker also synthesises @Just Always@ directly: each foreign name is bound
to an 'ObjectProp' marked 'Inline.Always' so the wrapper around the FFI object
is always inlined away (see
Note [Foreign bindings structure emitted by the Linker]).
-}
data Annotation = Always | Never
  deriving stock (Show, Eq, Ord)

type Parser = Megaparsec.Parsec Void Text

pragmaParser ∷ Parser Pragma
pragmaParser = do
  symbol "@inline"
  (,) <$> (nameParser <* sc) <*> annotationParser

annotationParser ∷ Parser Annotation
annotationParser = (Always <$ symbol "always") <|> (Never <$ symbol "never")

symbol ∷ Text → Parser ()
symbol = void . ML.symbol sc

sc ∷ Parser ()
sc = ML.space (MC.hspace1 @_ @Text) empty empty
