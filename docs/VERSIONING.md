# Versioning and releases

`pslua` follows the [Package Versioning Policy (PVP)][pvp], the versioning
convention of the Haskell ecosystem. We use one policy, in one shape, across
every artifact that carries a version, so the package, its tags, its releases,
and its changelog never disagree.

## The version number

A version is four components, `A.B.C.D`:

- `A.B` together are the **major** version. Bump them for any breaking change
  (a removed or changed compiler flag, a change in generated-Lua semantics, a
  breaking change to the public library API).
- `C` is the **minor** version. Bump it for backwards-compatible additions
  (a new flag, a new optimization that does not change existing output).
- `D` is the **patch** version. Bump it for changes that add nothing to the
  interface (bug fixes, internal refactors).

This is PVP, not Semantic Versioning. SemVer's three-component `A.B.C` and PVP's
four-component `A.B.C.D` look similar but split the "major" differently, so
mixing them is the one thing to avoid. If you find a version written as three
components anywhere, it is a mistake to correct, not a second convention.

## Where the version lives

The same string appears in all of these, and they must match:

- the `version:` field in `pslua.cabal`;
- the git tag for the release (for example `0.3.0.0`, without a `v` prefix, to
  match the existing tags);
- the GitHub release built from that tag;
- the section header in [`CHANGELOG.md`](../CHANGELOG.md).

Releases before `0.3.0.0` predate this policy: their tags are ad-hoc
(`0.2`, `0.1.2-alpha`) and the cabal `version:` had drifted away from them
entirely. `0.3.0.0` is where the four artifacts were unified; the historical
changelog sections keep their original tag names on purpose, because those are
the tags that actually exist.

## Cutting a release

1. Decide the new version from the nature of the changes (see above).
2. Bump `version:` in `pslua.cabal`.
3. Collect the changelog: `scriv collect --version <A.B.C.D>` assembles the
   fragments from `changelog.d/` into a new `CHANGELOG.md` section. (Until the
   fragment workflow is in routine use, the section may be written by hand in
   the same format.)
4. Merge to `main`.
5. Tag `main` with `<A.B.C.D>` (annotated) and create the GitHub release, using
   the new changelog section as the release notes.

[pvp]: https://pvp.haskell.org/
