let upstream-ps =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20260605/packages.dhall
        sha256:e48c9b283ca89ec994453459fb74c4b5b5a9432349f83a2e104f39dd869a0f6e

let upstream-lua =
      https://github.com/Unisay/purescript-lua-package-sets/releases/download/psc-0.15.15-20260613-2/packages.dhall
        sha256:b006e1fd8aa8cd290faf65852f37f62ad3bf5fe97fa3a7c30c97ff7ddfa49807

in  upstream-ps // upstream-lua
