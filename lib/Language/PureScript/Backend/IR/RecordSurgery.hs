{- | Fold @Record.Unsafe@ surgery over statically-known records
(issue #236).

A handwritten semantic layer for foreign record operations,
complementary to the source-derived lift
("Language.PureScript.Backend.Lua.ForeignLift"): the bodies of
@Record.Unsafe@'s exports are outside the liftable subset —
@unsafeGet@\/@unsafeHas@ index a table by a /dynamic/ key, which has no
IR form (a field read needs a static 'PropName'), and
@unsafeSet@\/@unsafeDelete@ copy their record with a @pairs@ loop — so
their semantics cannot be derived from the FFI source and are restated
here, keyed by qualified name and application-spine shape. Unlike the
lift, a handwritten registry /can/ drift from the package set, which is
why it is kept this small; the golden eval oracles pin the shipped
prelude's behaviour.

Each fold restates the fork FFI
(@purescript-lua-prelude@, @src/Record/Unsafe.lua@) at a site where
enough is static to decide it:

  * @unsafeGet l r@ /is/ @r[l]@ — with a static plain label that is
    exactly 'ObjectProp', for any record operand: the read is the
    call's entire body, so nothing about @r@ needs to be known. On a
    manifest operand the sibling fold then collapses the read to the
    field's value ('Language.PureScript.Backend.IR.Optimizer.reduceObjectProp').
  * @unsafeSet l v r@ copies @r@ and sets @l@; on a manifest literal
    the copy of the fresh table /is/ the extended literal, so one
    allocation replaces two.
  * @unsafeDelete l r@ copies @r@ dropping @l@ — on a manifest
    literal, the literal without the field.
  * @unsafeHas l r@ is @r[l] ~= nil@ — decidable on a manifest
    literal, whose fields are exactly known and whose values are never
    represented as @nil@ (the ecosystem-wide invariant that keeps
    PureScript values storable in Lua tables; see the @unit@ entry in
    docs\/QUIRKS.md).

A record operand that is not statically known leaves the copying
surgeries as calls. A label folds only when it is a string literal the
Lua lowering keeps verbatim (see 'plainLabel').

Like magic-do's canonical heads (Note [Canonical Effect\/ST heads]),
recognition is by qualified name alone: a build whose @Record.Unsafe@
is not the prelude's would be rewritten with the prelude's semantics.
-}
module Language.PureScript.Backend.IR.RecordSurgery
  ( foldRecordSurgery
  ) where

import Data.Char qualified as Char
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import Language.PureScript.Backend.IR.Linker (foreignAccessorQName)
import Language.PureScript.Backend.IR.Names
  ( ModuleName
  , Name (..)
  , PropName (..)
  , QName (..)
  , Qualified (Imported)
  , moduleNameFromString
  )
import Language.PureScript.Backend.IR.Types
  ( Ann
  , RawExp (..)
  , RewriteRuleM
  , unwindApp
  )
import Language.PureScript.Backend.Lua.Name qualified as Lua

{- | The rewrite rule. Strictly shrinking in every arm (an application
spine collapses into one of its operands or a literal), so it is
fixpoint-safe; it duplicates no subexpression, preserving unique
binders. Fires on both head shapes a foreign call has during
optimization: a reference to the accessor binding, and the dissolved
accessor itself — a field read off the module's @foreign@ import
(Note [Foreign bindings structure emitted by the Linker]).
-}
foldRecordSurgery ∷ Applicative m ⇒ RewriteRuleM m Ann
foldRecordSurgery =
  pure . \case
    expr@(AppN ann _ _)
      | (fn, args) ← unwindApp expr
      , Just surgery ← surgeryOf fn →
          case (surgery, args) of
            (Get, [label, r]) →
              plainLabel label <&> ObjectProp ann r
            (Set, [label, v, LiteralObject _ props]) →
              plainLabel label <&> \prop →
                LiteralObject ann (setField prop v props)
            (Delete, [label, LiteralObject _ props]) →
              plainLabel label <&> \prop →
                LiteralObject ann (filter ((/= prop) . fst) props)
            (Has, [label, LiteralObject _ props]) →
              plainLabel label <&> \prop →
                LiteralBool ann (any ((== prop) . fst) props)
            _ → Nothing
    _ → Nothing

data Surgery = Get | Set | Delete | Has

surgeryOf ∷ RawExp ann → Maybe Surgery
surgeryOf = \case
  Ref _ann (Imported modname name) → entryFor (QName modname name)
  expr → foreignAccessorQName expr >>= entryFor
 where
  entryFor ∷ QName → Maybe Surgery
  entryFor = (`Map.lookup` registry)

  registry ∷ Map QName Surgery
  registry =
    Map.fromList
      [ (QName recordUnsafe (Name "unsafeGet"), Get)
      , (QName recordUnsafe (Name "unsafeSet"), Set)
      , (QName recordUnsafe (Name "unsafeDelete"), Delete)
      , (QName recordUnsafe (Name "unsafeHas"), Has)
      ]

  recordUnsafe ∷ ModuleName
  recordUnsafe = moduleNameFromString "Record.Unsafe"

{- | The label, when it is a string literal the Lua lowering keeps
verbatim. Two conditions, both required:

  * Table keys pass through 'Language.PureScript.Backend.Lua.Name.makeSafe'
    at literal construction and at 'ObjectProp' reads, so a label
    @makeSafe@ would rewrite (a reserved word, a non-identifier) names
    a different key in generated tables than the raw string the
    foreign call looks up at runtime — folding such a label would
    change which key is read. 'Lua.fromText' succeeds exactly on the
    labels @makeSafe@ keeps.
  * A string literal's text is the escaped rendering
    ('Language.PureScript.PSString.decodeStringEscaping'), while a
    'PropName' carries the raw label; the two spellings coincide only
    when escaping is the identity. ASCII alphanumerics and @_@ are
    never escaped ('Lua.fromText' alone also admits non-ASCII
    letters, which are).
-}
plainLabel ∷ RawExp ann → Maybe PropName
plainLabel = \case
  LiteralString _ann label
    | Text.all plainChar label
    , isJust (Lua.fromText label) →
        Just (PropName label)
  _ → Nothing
 where
  plainChar ∷ Char → Bool
  plainChar c = Char.isAscii c && (Char.isAlphaNum c || c == '_')

{- | Replace the field in place when the label is present (keeping the
literal's field order), append it otherwise.
-}
setField
  ∷ PropName
  → RawExp ann
  → [(PropName, RawExp ann)]
  → [(PropName, RawExp ann)]
setField prop v props
  | any ((== prop) . fst) props =
      [(p, if p == prop then v else e) | (p, e) ← props]
  | otherwise = props <> [(prop, v)]
