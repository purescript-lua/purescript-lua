{- | This module defines the data type `Key` which is used to represent the
keys of a Lua table.
-}
module Language.PureScript.Backend.Lua.Key
  ( Key (..)
  , parser
  , toSafeName
  ) where

import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name
import Text.Megaparsec qualified as Mega
import Text.Megaparsec.Char qualified as M

{- Note [Lua reserved words as foreign export keys]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
An FFI foreign module exports its values through a Lua table, and a PureScript
identifier that collides with a Lua keyword (@if@, @for@, @end@, ...) has to
appear there as a bracketed string key: @{ ["for"] = ... }@. 'Key' captures
that distinction: 'KeyName' for an ordinary identifier, 'KeyReserved' for a
keyword read from @["..."]@ syntax.

The round-trip spans three modules, which must agree on the keyword set:

  * 'Language.PureScript.Backend.Lua.Name.reserved' is the authoritative set of
    Lua keywords, and 'Name.makeSafe' mangles one (e.g. @if@ becomes @_if_@).
  * 'parser' below reads a bracketed-quoted key as 'KeyReserved' by matching
    against that set, and a bare identifier as 'KeyName'.
  * 'toSafeName' maps a 'Key' back to a safe 'Name': 'KeyName' passes through,
    'KeyReserved' goes through 'Name.makeSafe'. The Lua backend uses the result
    as the export's table field name, so a reserved key reaches the generated
    table as a mangled but valid identifier.
-}
data Key = KeyName Name | KeyReserved Text
  deriving stock (Eq, Show)

toSafeName ∷ Key → Name
toSafeName (KeyName n) = n
toSafeName (KeyReserved t) = Name.makeSafe t

type Parser = Mega.Parsec Void Text

parser ∷ Parser Key
parser = (nameParser <|> reservedParser) <* M.space
 where
  nameParser ∷ Parser Key
  nameParser = KeyName <$> Name.parser

  reservedParser ∷ Parser Key
  reservedParser = brackets $ quotes do
    KeyReserved <$> Mega.choice (M.string <$> toList Name.reserved)

  brackets ∷ Parser a → Parser a
  brackets = between '[' ']'

  quotes ∷ Parser a → Parser a
  quotes = between '\"' '\"'

  between ∷ Char → Char → Parser c → Parser c
  between open close p = char open *> p <* char close

  char ∷ Char → Parser ()
  char c = M.char c *> M.space
