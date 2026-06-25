<!-- Describe the change and link the issue it closes, if any. -->

## Summary

## Checklist

- [ ] Added a `changelog.d/` fragment for any user-facing change (`scriv create`
      in the dev shell), or this change ships nothing releasable (CI, docs, or an
      internal refactor).
- [ ] In the dev shell (`nix develop`), `fourmolu -i lib/ exe/ test/` and
      `hlint lib/ exe/ test/` are clean.
- [ ] In the dev shell, `cabal test all` passes; structural goldens were
      re-accepted on purpose if codegen moved (`PSLUA_GOLDEN_ACCEPT=1`), and
      `eval/golden.txt` still holds.
