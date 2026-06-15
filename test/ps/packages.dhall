let upstream-ps =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20260605/packages.dhall
        sha256:e48c9b283ca89ec994453459fb74c4b5b5a9432349f83a2e104f39dd869a0f6e

let upstream-lua =
      https://github.com/purescript-lua/purescript-lua-package-sets/releases/download/psc-0.15.15-20260615-2/packages.dhall
        sha256:da1998fd6cf7c411b8decb16d2be5a8b1499a0789e1ac5a2790d2ad9868aaf6e

in  upstream-ps // upstream-lua
