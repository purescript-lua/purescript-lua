{- | This module defines the data type `Key` which is used to represent the
keys of a Lua table.
-}
module Language.PureScript.Backend.Lua.Key
  ( Key (..)
  , toSafeName
  ) where

import Language.PureScript.Backend.Lua.Name (Name)
import Language.PureScript.Backend.Lua.Name qualified as Name

{- Note [Lua reserved words as foreign export keys]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
An FFI foreign module exports its values through a Lua table, and a PureScript
identifier that collides with a Lua keyword (@if@, @for@, @end@, ...) has to
appear there as a bracketed string key: @{ ["for"] = ... }@. 'Key' captures
that distinction: 'KeyName' for an ordinary identifier, 'KeyReserved' for a
keyword read from @["..."]@ syntax.

The round-trip spans three modules, which must agree on the keyword set:

  * 'Language.PureScript.Backend.Lua.Name.reserved' is the reserved-word set the
    backend escapes against -- the Lua 5.1 keywords plus @goto@, which Lua
    5.2+ and LuaJIT reserve: generated names and parsed FFI names share one
    output chunk, and mangling @goto@ keeps that chunk loadable there (the
    compiler's Lua parser rejects it as an identifier for the same reason) --
    and 'Name.makeSafe' mangles one (e.g. @if@ becomes @_if_@).
  * 'Language.PureScript.Backend.Lua.Linker.Foreign.interpretForeignModule'
    reads a parsed export-table row with a bracketed string key as
    'KeyReserved' by matching against that set, and a bare identifier row as
    'KeyName'.
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
