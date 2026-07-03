{
  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    purescript-overlay.url = "github:thomashoneyman/purescript-overlay";
    purescript-overlay.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    tricorder.url = "github:atelier-hub/tricorder";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      haskellNix,
      purescript-overlay,
      treefmt-nix,
      tricorder,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system overlays;
          inherit (haskellNix) config;
        };
        overlays = [
          haskellNix.overlay
          purescript-overlay.overlays.default
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
                  purs-bin.purs-0_15_16
                  spago-bin.spago-1_0_4
                  lua51Packages.lua
                  lua51Packages.luacheck
                  nil
                  scriv
                  upx
                  yamlfmt
                  tricorder.packages.${system}.tricorder
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
      "https://atelier.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "purescript-lua.cachix.org-1:yLs4ei2HtnuPtzLekOrW3xdfm95+Etw15gwgyIGTayA="
      "atelier.cachix.org-1:rEyd/Z4TiXZbBVuU/lDnKZ/7WtnFTwJ17OKHGcahVUo="
    ];
    allow-import-from-derivation = "true";
  };
}
