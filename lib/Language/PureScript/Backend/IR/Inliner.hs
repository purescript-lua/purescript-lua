module Language.PureScript.Backend.IR.Inliner where

import Language.PureScript.Backend.IR.Names (Name, nameParser)
import Text.Megaparsec qualified as Megaparsec
import Text.Megaparsec.Char qualified as MC
import Text.Megaparsec.Char.Lexer qualified as ML

type Pragma = (Name, Annotation)

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
