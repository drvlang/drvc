# drvc

Build a Meson C project once and share the result through your Nix binary cache. drvc reads Meson's hashed wrap archives, runs Ninja and the project's Meson tests, and installs the resulting programs and libraries. In a monorepo, each command can have its own source file set.

## Try it with mmdoc

Enable `nix-command flakes ca-derivations dynamic-derivations recursive-nix` on your Nix client and daemon, and add `recursive-nix` to the builder's system features. drvc provides outputs for x86-64 and AArch64 on Linux and macOS.

```sh
git clone https://github.com/ryantm/mmdoc
nix run github:drvlang/drvc -- build -C mmdoc -o result
nix run github:drvlang/drvc -- test -C mmdoc -- --verbose
nix run github:drvlang/drvc -- run -C mmdoc -- mmdoc mmdoc/doc ./manual
```

Open `manual/multi/index.html` to read the generated manual. In the mmdoc checkout, `nix build`, `nix flake check`, and `nix run . -- mmdoc doc ./manual` use the flake's pinned drvc.

## Use it in your project

A C project with a `meson.build` can use the CLI directly. When the project needs system libraries or tools, record their Nixpkgs names in an optional `drvlang.json`. Use `files` to include only sources, build definitions, assets and tests read by that project. For example, mmdoc uses:

```json
{
  "drvc": {
    "files": ["meson.build", "src", "test"],
    "libraries": ["cmark-gfm", "libfastjson", "libzip"],
    "tools": ["xxd"],
    "program": "mmdoc"
  }
}
```

`program` selects the executable when a build installs more than one. A single-project flake can reuse the same file list:

```nix
{
  inputs.drvc.url = "github:drvlang/drvc";
  outputs = { drvc, ... }: drvc.lib.mkFlake { root = ./.; };
}
```

For dependencies fetched from source, include `subprojects` in the file list. drvc supports public HTTPS Meson `[wrap-file]` archives with SHA-256 source and patch hashes. Update the native wrap to change a dependency. A Rust planner turns the wraps into Nix fetches during the build, and Meson runs with downloads disabled. The flake lock pins Nixpkgs libraries and tools.

## Monorepos

Map names to Meson member directories in `drvlang.json`. Use `files` for shared code and `targetFiles` for sources specific to each command. The root Meson project in the [working example](tests/workspace) enters each command directory when it exists.

```json
{
  "commands": { "api": "cmd/api", "worker": "cmd/worker" },
  "drvc": {
    "files": ["meson.build", "pkg"],
    "targetFiles": { "api": ["cmd/api"], "worker": ["cmd/worker"] }
  }
}
```

Use `drvc.lib.mkMonorepoFlake { root = ./.; }` for this layout. Run `drvc test api` or `nix build .#api`. An edit to the worker preserves the API's package and check paths. Within one selected target, Ninja compiles the C objects in a single Nix build.

For Nix-defined configurations, `mkPackage`, `mkTest` and `mkApp` accept a `system` and an explicit `src` from `drvc.lib.projectSource`. `mkMonorepoFlake` also accepts a `commands` map and a `srcForTarget` function. [Per-target Nix example](tests/default.nix)

## Benchmark

`nix run .#bench -- --runs 5` builds [a pinned mmdoc revision](https://github.com/ryantm/mmdoc/tree/684ba64be908128d2092dfd13675397d4272b349), runs its upstream tests, and renders its own documentation. Each timed trial repeats the manual render and checks both HTML formats and the search asset, with the compiler and mmdoc already cached. [Benchmark definition](benchmarks/default.nix)
