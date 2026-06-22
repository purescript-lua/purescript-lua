{ name = "test-project"
, dependencies =
  [ "console"
  , "effect"
  , "either"
  , "enums"
  , "foldable-traversable"
  , "maybe"
  , "partial"
  , "newtype"
  , "prelude"
  , "profunctor"
  , "strings"
  , "tailrec"
  , "transformers"
  , "tuples"
  ]
, packages = ./packages.dhall
, sources = [ "golden/**/*.purs" ]
}
