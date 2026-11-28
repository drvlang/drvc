# Optimizing drvc for CI

Across all seven CIBench CI cases, updating `drvc` to the optimized `drvcpp` Meson builder (`7b13e6e`, replacing the Rust/Cargo wrap planner, `drvkit/dynamic.nix`, `nix-instantiate`, `nixpkgsSource`, `jq`, and `linkFarm` with a self-contained Python 3 stdlib direct Nix daemon ATerm planner) reduced cold builds from 55.38 s to 4.16 s (13.31× faster), remote cache restores from 18.91 s / 974.7 MiB to 3.37 s / 208.3 MiB (5.61× faster, 78.6% less traffic), local warm checks from 1.27 s to 0.86 s (1.48× faster), remote edits from 46.64 s / 974.7 MiB to 5.12 s / 208.3 MiB (9.11× faster, matching `stdenv.mkDerivation` transfer byte-for-byte), local edits from 26.98 s to 2.70 s (9.99× faster), remote dependency updates from 47.06 s / 982.2 MiB to 5.30 s / 208.2 MiB (8.88× faster, 78.8% less traffic and less than `stdenv.mkDerivation`'s 215.8 MiB), and local dependency updates from 27.00 s to 2.89 s (9.34× faster).

CIBench builds a C Meson executable (`parse-ini`) depending on the `inih` wrap subproject and checks its output. The source edit modifies `main.c` and the expected output without changing `meson.build` or `subprojects/inih.wrap`. The independent dependency update upgrades `inih` from `r62` to `r63` in `subprojects/inih.wrap` without any separate Nix hash.

| CIBench case | drvc `5547336` (s) | drvc optimized (s) | `stdenv.mkDerivation` (s) | drvc cache transfer (before → after) | drvc builds (before → after) | drvc peak RAM (before → after) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold | 55.38 | 4.16 | 3.52 | 0.0 → 0.0 MiB | 22 → 5 | 4395 → 1060 MiB |
| remote-warm | 18.91 | 3.37 | 1.17 | 974.7 → 208.3 MiB | 0 → 0 | 4132 → 1024 MiB |
| local-warm | 1.27 | 0.86 | 0.84 | 0.0 → 0.0 MiB | 0 → 0 | 418 → 321 MiB |
| edit-remote | 46.64 | 5.12 | 4.90 | 974.7 → 208.3 MiB | 5 → 4 | 4160 → 1058 MiB |
| edit-local | 26.98 | 2.70 | 2.48 | 0.0 → 0.0 MiB | 5 → 4 | 533 → 360 MiB |
| dependency-remote | 47.06 | 5.30 | 4.95 | 982.2 → 208.2 MiB | 7 → 5 | 4183 → 1054 MiB |
| dependency-local | 27.00 | 2.89 | 2.75 | 0.0 → 0.0 MiB | 7 → 5 | 533 → 357 MiB |

Times are medians of two trials for `5547336`, three trials for the optimized tree, and five trials for the shared Nixpkgs `stdenv.mkDerivation` comparator, run in alternating order (`before-1`, `after-1` ×2, `before-2`, `after-2`) with no competing host workloads. Both builders used GCC 15.2.0, Meson 1.10.2, and Ninja 1.13.2. Each sample timed evaluation and realization of the package and check together. [Individual timings, build counts, cache traffic, peak memory, and realized outputs](cibench-ci-optimizations-2026-11-27.csv)

## Summary of optimizations

1. **Adopted direct Python 3 Nix daemon ATerm Meson planner (`flake.lock` -> `drvcpp` `7b13e6e`)**: Eliminated `rustPlatform.buildRustPackage` (`rustc-1.95.0`, `rustc-bootstrap`, `cargo`, `llvm-lib`, 30+ crates), `pkgs.nix`, `nixpkgsSource` (202 MiB), `boost`, `icu4c`, `aws-sdk`, `curl`, `jq`, and `linkFarm` from `drvc` consumer builds.
2. **Direct `builtin:fetchurl` wrap archives and zero-`stdenv` CA forwarder (`drvcpp` `7b13e6e`)**: Fetches Meson wrap archives via `builtin:fetchurl`, introspects `meson-info/intro-*.json` with Python stdlib `json`, and replaces `pkgs.runCommand` (`stdenv-linux-no-cc`) and `bash-interactive` with a `python3 -S` CA wrapper and `bashNonInteractive`, cutting `cold` peak RAM from 4395 MiB to 1060 MiB.

## Correctness checks

- Realized package and check outputs were deterministic across all three optimized trials and matched between `cold`, `remote-warm`, and `local-warm`, between `edit-remote` and `edit-local`, and between `dependency-remote` and `dependency-local`.
- `nix flake check -L --option allow-import-from-derivation false` passed all checks:
  - `checks.x86_64-linux.benchmark` (`mmdoc` 0.27.0 C manual generator with `cmark-gfm` library and multi/single-page HTML verification)
  - `checks.x86_64-linux.workspace` (multi-member C Meson workspace `api` and `worker` sharing `pkg`)
  - `checks.x86_64-linux.cli`
- `nix flake show --all-systems` (`x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`) and `tests/integration.sh` (source isolation, `drvc build`/`run`/`test`, failing test exit propagation, and `inih.wrap` `r62` → `r63` lockfile update) passed.

## Reproduction

The runner used x86_64 Linux, an Intel Core i7-1280P, Nix 2.35.3, four logical CPUs (16–19), four jobs, four cores per builder, 8 GiB RAM, and zero swap. Sandboxing was enabled and IFD disabled. The simulated project cache used 5 ms latency and 100 MiB/s aggregate bandwidth. Both builders used the same local mirror of signed NixOS packages populated from `drvkit/cibench/results/bootstrap/c.txt`. Cold jobs started with an empty local store and project cache. Subsequent cases independently used the original job's local store or its published project cache. The recorded runner was `/nix/store/vpysz8ih9lhm154cjaamrncwjn08njp6-cibench-0.1.0`.

```sh
work=$(mktemp -d)
stock="file://$work/stock"
nix copy --from https://cache.nixos.org --to "$stock?compression=zstd&compression-level=1" \
  --stdin < ../drvkit/cibench/results/bootstrap/c.txt
runner="$(nix build --impure --no-link --print-out-paths -f ../drvkit/cibench)/bin/cibench"
mkdir "$work/before"
git archive 5547336 | tar -x -C "$work/before"
run() {
  taskset -c 16-19 "$runner" c --builder "$1" --out "$work/$2" --trials "$3" \
    --cpus 4 --memory-mib 8192 --latency-ms 5 --bandwidth-mib-s 100 \
    --upstream "$stock?priority=40"
}
run "$work/before" before-1 1
run "$PWD" after-1 2
run "$work/before" before-2 1
run "$PWD" after-2 1
```
