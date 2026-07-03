module Language.PureScript.Backend.IR.Names
  ( module Reexport
  , Name (..)
  , discardName
  , nameParser
  , QName (..)
  , printQName
  , TyName (..)
  , CtorName (..)
  , FieldName (..)
  , PropName (..)
  , Qualified (..)
  , qualifiedQName
  ) where

import Data.Char (isAlphaNum)
import Language.PureScript.Names as Reexport
  ( ModuleName (..)
  , moduleNameFromString
  , runModuleName
  )
import Quiet (Quiet (..))
import Text.Megaparsec qualified as Megaparsec
import Prelude hiding (show)

newtype Name = Name {nameToText ∷ Text}
  deriving newtype (Eq, Ord)
  deriving stock (Generic)
  deriving (Show) via (Quiet Name)

nameParser ∷ Megaparsec.Parsec Void Text Name
nameParser = Name <$> Megaparsec.takeWhile1P (Just "name char") isAlphaNum

{- | The binder for the (unused) result of a discarded action, minted by
the magic-do transform: @_@ is the conventional Lua throwaway, exempt
from luacheck's unused-local check. Many such binders may coexist in one
top-level binding, so the @UniqueBinders@ lint exempts this name — sound
only while nothing ever references it, which the same lint checks.
PureScript sources cannot produce a binder of this name: @_@ is not a
valid PS identifier, and compiler-generated unused idents arrive as
@$__unused@ and become 'ParamUnused' parameters.
-}
discardName ∷ Name
discardName = Name "_"

data QName = QName {qnameModuleName ∷ ModuleName, qnameName ∷ Name}
  deriving stock (Eq, Ord, Show)

printQName ∷ QName → Text
printQName QName {..} =
  runModuleName qnameModuleName <> "∷" <> nameToText qnameName

newtype TyName = TyName {renderTyName ∷ Text}
  deriving newtype (Eq, Ord)
  deriving stock (Generic)
  deriving (Show) via (Quiet TyName)

newtype CtorName = CtorName {renderCtorName ∷ Text}
  deriving newtype (Eq, Ord)
  deriving stock (Generic)
  deriving (Show) via (Quiet CtorName)

-- TODO: is it used at all?
newtype FieldName = FieldName {renderFieldName ∷ Text}
  deriving newtype (Eq, Ord)
  deriving stock (Generic)
  deriving (Show) via (Quiet FieldName)

newtype PropName = PropName {renderPropName ∷ Text}
  deriving newtype (Eq, Ord)
  deriving stock (Generic)
  deriving (Show) via (Quiet PropName)

data Qualified a = Local a | Imported ModuleName a
  deriving stock (Show, Eq, Ord, Functor)

qualifiedQName ∷ QName → Qualified Name
qualifiedQName QName {qnameModuleName, qnameName} =
  Imported qnameModuleName qnameName
