{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  # Haskell (fourmolu) is deliberately NOT wired into `nix fmt`. fourmolu's
  # --haddock-style is global (single-line | multi-line | multi-line-compact)
  # with no per-comment or by-length mode, so any choice rewrites the
  # hand-authored Haddock — single-line line-prefixes long block comments
  # (annoying to copy), while multi-line bloats short ones. The source keeps a
  # deliberate mix (short `-- |`, long `{- | … -}`), so Haskell stays a manual
  # `fourmolu -i lib/ exe/ test/` step the author runs when they choose.
  programs.cabal-fmt.enable = true;
  programs.nixfmt.enable = true;
  programs.yamlfmt.enable = true;
  programs.dhall.enable = true; # test/ps/{packages,spago}.dhall

  # Generated goldens are committed; never reformat them. (test/ps/.spago is
  # gitignored, so treefmt's git-aware walk already skips it.)
  settings.global.excludes = [
    "test/ps/output/**"
    "dist-newstyle/**"
    "result"
    # yamlfmt strips the trailing template comments from .hlint.yaml; keep it
    # hand-maintained.
    ".hlint.yaml"
  ];
}
