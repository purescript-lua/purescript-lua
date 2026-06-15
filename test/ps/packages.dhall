let upstream-ps =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20260605/packages.dhall
        sha256:e48c9b283ca89ec994453459fb74c4b5b5a9432349f83a2e104f39dd869a0f6e

let upstream-lua =
      https://github.com/purescript-lua/purescript-lua-package-sets/releases/download/psc-0.15.15-20260615/packages.dhall
        sha256:76624f5210200039e6510b8b7666851cfe4d665fab75bf65707474bd53ca5c8a

in  upstream-ps // upstream-lua
