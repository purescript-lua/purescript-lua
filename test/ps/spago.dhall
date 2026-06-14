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
  , "tailrec"
  ]
, packages = ./packages.dhall
, sources = [ "golden/**/*.purs" ]
}
