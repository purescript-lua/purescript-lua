{
  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    easy-purescript-nix.url = "github:justinwoo/easy-purescript-nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      haskellNix,
      easy-purescript-nix,
      treefmt-nix,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        easy-ps = easy-purescript-nix.packages.${system};
        pkgs = import nixpkgs {
          inherit system overlays;
          inherit (haskellNix) config;
        };
        overlays = [
          haskellNix.overlay
          (final: prev: {
            psluaProject = final.haskell-nix.project' {
              src = ./.;
              compiler-nix-name = "ghc98";
              evalSystem = "x86_64-linux";
              modules =
                let
                  prof = false;
                in
                [
                  {
                    doHaddock = false;
                    doHoogle = false;
                    enableProfiling = prof;
                    enableLibraryProfiling = prof;
                  }
                ];

              name = "purescript-lua";

              shell = {
                tools = {
                  cabal = { };
                  fourmolu = { };
                  hlint = { };
                  haskell-language-server = { };
                };
                buildInputs = with pkgs; [
                  cachix
                  easy-ps.purs-0_15_16-0
                  easy-ps.spago
                  lua51Packages.lua
                  lua51Packages.luacheck
                  nil
                  upx
                  yamlfmt
                ];
                # `nix fmt` runs treefmt (treefmt.nix). Robust pre-commit hook:
                # point git at the tracked .githooks/ dir (works in worktrees/
                # submodules; never clobbers an existing .git/hooks/pre-commit).
                shellHook = "git config core.hooksPath .githooks";
              };

              crossPlatforms =
                p:
                pkgs.lib.optionals pkgs.stdenv.hostPlatform.isx86_64 (
                  pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ p.musl64 ]
                );
            };
          })
        ];
        flake = pkgs.psluaProject.flake { };
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      flake
      // {
        legacyPackages = pkgs;
        packages.default = flake.packages."pslua:exe:pslua";
        packages.static = flake.ciJobs.x86_64-unknown-linux-musl.packages."pslua:exe:pslua";
        formatter = treefmtEval.config.build.wrapper;
      }
    );

  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://purescript-lua.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "purescript-lua.cachix.org-1:yLs4ei2HtnuPtzLekOrW3xdfm95+Etw15gwgyIGTayA="
    ];
    allow-import-from-derivation = "true";
  };
}
