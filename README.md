# Purescript Backend for Lua

[![Purescript Lua CI](https://github.com/purescript-lua/purescript-lua/actions/workflows/ci.yaml/badge.svg)](https://github.com/purescript-lua/purescript-lua/actions/workflows/ci.yaml)

🔋 Status: (2026-06-25) usable as a [Spago](https://github.com/purescript/spago) backend against the published [Lua package set](https://github.com/purescript-lua/purescript-lua-package-sets). Still pre-1.0: it likely contains bugs, but `spago build`/`run`/`test` already target Lua out of the box. See the [changelog](./CHANGELOG.md) for what changed in each release.

💡 If you have an idea on how to use Purescript to Lua compilation please contribute it here:
https://github.com/purescript-lua/purescript-lua/discussions/categories/ideas

## Features

- [x] Lua code bundling: emits either a Lua module (a file that returns a table with functions) or an application (a file that executes itself).
- [x] FFI with Lua.
- [x] Dead Code Elimination (DCE).
- [x] Code inlining, tunable with graduated `@inline` directives
      (`always`/`never`/`arity=N`, per-field accessors, a project-wide
      `--directives` file, and a shipped default pack for the prelude/core
      forks).
- [x] [Package Set](https://github.com/purescript-lua/purescript-lua-package-sets) for PureScript/Lua libs.
- [x] All core libs added to the package set.
- [x] First-class [Spago](https://github.com/purescript/spago) backend: `spago build`, `spago run`, and `spago test` target Lua via `pslua`.

## Quick Start

For the moment the best way to start is to use `nix` to install `pslua`.

Consider configuring [Cachix](https://docs.cachix.org/installation) as a binary nix cache to avoid rebuilding a ton of dependencies:

```
cachix use purescript-lua
```
You can use this [template repository](https://github.com/purescript-lua/purescript-lua-template) to initialize your project.

Here is another [example](https://github.com/purescript-lua/purescript-lua-example) project: Nginx server running Lua code using [OpenResty](https://openresty.org/).

If you use [Spago](https://github.com/purescript/spago) to build your PureScript project, configure `pslua` as a custom backend in `spago.yaml`. The package set is the published [Lua package set](https://github.com/purescript-lua/purescript-lua-package-sets) (the registry baseline with the Lua FFI forks overlaid), consumed via `workspace.packageSet.url`. Assuming `pslua` is on your PATH:

<details> <summary>spago.yaml</summary>

```yaml
package:
  name: acme-project
  dependencies:
    - effect
    - prelude
workspace:
  packageSet:
    url: https://github.com/purescript-lua/purescript-lua-package-sets/releases/download/psc-0.15.15-20260624/packages.json
  backend:
    cmd: pslua
    args:
      - --foreign-path
      - .
      - --ps-output
      - output
      - --lua-output-file
      - dist/main.lua
      - --entry
      - Main.main
```

</details>

With a backend configured, Spago compiles the project to CoreFn and then runs the backend command, so `spago build` links the result into `dist/main.lua`. `spago run` additionally executes the entry point: Spago invokes `pslua --run Main.main`, which compiles and runs it with `lua`, forwarding lua's exit code. (`--run` needs an application entry point `<Module>.<binding>`.)

### Using nix with flakes

```
nix run 'github:purescript-lua/purescript-lua' -- --help
```

## Installation

If you're on a x86 64bit Linux system then you can grab the latest pre-built
`pslua-linux_x86_64.tar.gz` from the [latest release](https://github.com/purescript-lua/purescript-lua/releases/latest)
(when one is attached), or browse all [releases](https://github.com/purescript-lua/purescript-lua/releases).

alternatively,

### Using nix with flakes

```
nix profile install 'github:purescript-lua/purescript-lua'
```

will make `pslua` executable available for use.

### Windows

Nix build won't work on Windows so you'd first need to  install
`cabal` and `ghc-9.8.4` (One way of installing those is [GHCUp](https://www.haskell.org/ghcup/)).

Once the pre-requisites are available on your PATH
you run

```
cabal install exe:pslua

.... elided ....

Installing   commutative-semigroups-0.1.0.1 (lib)
Installing   primes-0.2.1.0 (all, legacy fallback)
Installing   base16-bytestring-1.0.2.0 (lib)
Installing   quiet-0.2 (lib)
Completed    newtype-0.2.2.0 (lib)

.... elided ....

Starting     pslua-0.3.0.0 (exe:pslua)
Building     pslua-0.3.0.0 (exe:pslua)
Installing   pslua-0.3.0.0 (exe:pslua)
Completed    pslua-0.3.0.0 (exe:pslua)
Copying 'pslua.exe' to 'C:\cabal\bin\pslua.exe'
```

This will build and install executable `pslua.exe`

```
C:\cabal\bin\pslua --help
pslua - a PureScript backend for Lua

Usage: pslua [--foreign-path FOREIGN-PATH] [--ps-output PS-PATH]
             [--lua-output-file LUA-OUT-FILE] [--directives DIRECTIVES-FILE]
             [--output-lua-ast] [--output-ir] [--lint-ir] [--max-locals N]
             [--max-upvalues N] [-e|--entry ENTRY] [--run ENTRY]

  Compile PureScript's CoreFn to Lua

Available options:
  --foreign-path FOREIGN-PATH
                           Path to a directory containing foreign files.
                           Default: foreign
  --ps-output PS-PATH      Path to purs output directory.
                           Default: output
  --lua-output-file LUA-OUT-FILE
                           Path to write compiled Lua file to.
                           Default: main.lua
  --directives DIRECTIVES-FILE
                           Path to a file with project-wide inlining directives,
                           one per line: <Module>.<binding><accessor?> <mode>
                           - accessor: .label or ...label
                           - mode: default | never | always | arity=N
                             Example: Data.Lens.over arity=2
                           A local module-header pragma overrides the file;
                           the file overrides @inline export pragmas.
  --output-lua-ast         Output Lua AST.
                           Default: false
  --output-ir              Output IR.
                           Default: false
  --lint-ir                Check IR invariants after every optimizer pass (debug).
                           Default: false
  --max-locals N           Target Lua VM's hard limit on local variables
                           per function (LUAI_MAXVARS).
                           Default: 200 (Lua 5.1)
  --max-upvalues N         Target Lua VM's hard limit on upvalues
                           per function (LUAI_MAXUPVALUES).
                           Default: 60 (Lua 5.1)
  -e,--entry ENTRY         Where to start compilation.
                           Could be one of the following formats:
                           - Application format: <Module>.<binding>
                             Example: Acme.App.main
                           - Module format: <Module>
                             Example: Acme.Lib
                           Default: Main.main
  --run ENTRY              Compile the given application entry point and run it with
                           lua, forwarding lua's exit code.
                           This is what spago run invokes.
                           Format: <Module>.<binding>
                             Example: Acme.App.main
  -h,--help                Show this help text
```

## Inlining directives

The optimizer's inlining decisions can be tuned per binding with `@inline`
directives. A directive names a target, optionally an accessor selecting one
field of a record the binding is (or returns), and a mode:

```
@inline [export] name[.label|...label] (default | never | always | arity=N)
```

- `always` / `never` force or forbid inlining the target.
- `arity=N` inlines the target only at call sites applying at least N
  arguments — a partial application stays a shared reference. This is the
  switch that starts an abstraction-elimination cascade: the pasted body
  meets beta reduction and the case-of-known-constructor folds, so wrappers
  like `runOp (Op f) x` collapse to `f x` at every saturated site.
- `.label` targets one field of a dictionary-record binding, `...label` one
  field of the record a binding returns when applied (`f(x).label`) — a
  policy for a single method rather than the whole record.
- `default` explicitly resets the target to the built-in heuristics, masking
  any weaker directive.

Directives come from four sources, most specific first:

1. **Module-header pragmas** — comment lines above `module` in the defining
   module, naming its own bindings: `-- @inline myBinding arity=2`.
2. **A project directives file** (`--directives inline.txt`) — one directive
   per line with fully-qualified names and no `@inline` prefix
   (`Data.Lens.over arity=2`); `--` comments and blank lines are allowed.
   Entries that match nothing in the build are ignored, so a shared file can
   cover optional dependencies.
3. **Exported pragmas** — `-- @inline export myBinding always` in the
   defining module travels with the library as its author's recommendation.
4. **The default directive pack** — the compiler ships directives for the
   prelude/core forks' ubiquitous tiny combinators (class member accessors
   like `map` and `bind` at `arity=1`, `bindFlipped`, the function-instance
   dictionary methods like `semigroupFn.append`, `otherwise`, the generics
   glue, the ST/Ref `modify` wrappers), so common dictionary-parameterized
   code specializes away with no annotations in user code.

A local pragma beats the file, the file beats an exported pragma, and every
explicit source beats the default pack, per target. To opt a pack entry out,
name it in the directives file with mode `default` (restoring the built-in
heuristics) or any stronger mode. Foreign bindings accept only whole-binding
`always`/`never`/`default` (their implementation is opaque to the optimizer).
Note that `spago run` re-invokes the backend without build-phase flags, so
`--directives` (like all build flags) applies to `spago build` output, not to
the `--run` re-link.

Specializations of an `arity=N` target need no directives of their own: a
top-level binding that applies the target to `k` arguments — a hand-written
partial application, or the binding the PureScript compiler's CSE floats for
a repeated dictionary application — inherits `arity=(N-k)` while
under-applied and `always` once saturated, transitively through chains of
such bindings. An explicit directive on the specialization overrides the
derived one.
