{ name = "test-project"
, dependencies =
  [ "console"
  , "effect"
  , "enums"
  , "foldable-traversable"
  , "maybe"
  , "partial"
  , "newtype"
  , "prelude"
  , "profunctor"
  , "strings"
  ]
, packages = ./packages.dhall
, sources = [ "golden/**/*.purs" ]
}
