#!/usr/bin/env bash
set -euo pipefail
# Run from the drvc checkout. Build and test through the public CLI and a
# downstream flake, including a native lock update and an unrelated file edit.
export NIX_CONFIG="${NIX_CONFIG:-}
allow-import-from-derivation = false"
tool=$(nix flake archive --json | jq -er .path)
cli=$(nix build --no-link --print-out-paths .#drvc)/bin/drvc
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cp -R tests/workspace "$fixture/workspace"
cd "$fixture/workspace"
cat > flake.nix <<NIX
{
  inputs.drvc.url = "path:$tool";
  outputs = { drvc, ... }: drvc.lib.mkMonorepoFlake { root = ./.; };
}
NIX
system=$(nix eval --impure --raw --expr 'builtins.currentSystem')
nix flake lock
drv_path() {
  nix eval --raw "path:$PWD#$1.$system.$2.drvPath"
}
for output in packages checks; do
  api=$(drv_path "$output" api)
  worker=$(drv_path "$output" worker)
  echo notes >> README.md
  [[ $(drv_path "$output" api) == "$api" && $(drv_path "$output" worker) == "$worker" ]]
  echo '/* edit the worker */' >> cmd/worker/main.c
  [[ $(drv_path "$output" api) == "$api" && $(drv_path "$output" worker) != "$worker" ]]
  worker=$(drv_path "$output" worker)
  echo '/* edit shared code */' >> pkg/shared.h
  [[ $(drv_path "$output" api) != "$api" && $(drv_path "$output" worker) != "$worker" ]]
done

nix flake check "path:$PWD"
for target in api worker; do
  pkg=$(nix build --no-link --print-out-paths "path:$PWD#$target")
  [[ $("$cli" build -C . "$target" --no-link) == "$pkg" ]]
  [[ $("$cli" run -C . "$target" -- 'two words') == "$target shared two words" ]]
  [[ $(nix run "path:$PWD#$target" -- 'two words') == "$target shared two words" ]]
  "$cli" test -C . "$target" -- --verbose
done
sed 's/return 0;/return 7;/' cmd/api/main.c > cmd/api/fail.c
mv cmd/api/fail.c cmd/api/main.c
if "$cli" test -C . api >"$fixture/failure.log" 2>&1; then
  echo 'drvc test accepted a failing C test' >&2
  exit 1
fi
grep -Eq 'FAIL|exit status 7' "$fixture/failure.log" || { cat "$fixture/failure.log"; exit 1; }
"$cli" test -C . worker

cp -R "$tool/tests/wrap" "$fixture/wrap"
chmod -R u+w "$fixture/wrap"
cd "$fixture/wrap"
cat > flake.nix <<NIX
{
  inputs.drvc.url = "path:$tool";
  outputs = { drvc, ... }: drvc.lib.mkFlake {
    src = drvc.lib.projectSource {
      root = ./.;
      files = [ ./meson.build ./main.c ./subprojects ];
    };
  };
}
NIX
nix flake lock
before=$(nix eval --raw "path:$PWD#packages.$system.default.drvPath")
for release in 62 63; do
  if [[ $release == 63 ]]; then
    cp updates/inih.wrap subprojects/inih.wrap
    [[ $(nix eval --raw "path:$PWD#packages.$system.default.drvPath") != "$before" ]]
  fi
  [[ $(nix run "path:$PWD") == 42 ]]
  "$cli" test -C .
done
