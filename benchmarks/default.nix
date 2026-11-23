{ self, system, pkgs }:
let
  upstream = builtins.fetchTree {
    type = "github"; owner = "ryantm"; repo = "mmdoc";
    rev = "f9f360bb2565a6bf1c01e63a3d68109b6dd00257"; # 0.27.0
    narHash = "sha256-aq/+/geFENuDHk5yu6eFw5/TKpAANMO0kVcdq8uSW/c=";
  };
  root = /. + builtins.unsafeDiscardStringContext upstream.outPath;
  mmdoc = self.lib.mkPackage {
    inherit system;
    src = self.lib.projectSource {
      inherit root;
      files = map (file: root + "/${file}") [ "meson.build" "src" "test" ];
    };
    buildInputs = with pkgs; [ cmark-gfm libfastjson libzip ];
    nativeBuildInputs = [ pkgs.xxd ];
  };
in pkgs.runCommand "drvc-mmdoc-manual" {} ''
  ${mmdoc}/bin/mmdoc mmdoc ${root + "/doc"} manual
  grep -Fq 'Minimal Markdown Documentation' manual/single/index.html
  grep -Fq 'contributing/' manual/multi/index.html
  test -s manual/multi/contributing/index.html
  test -s manual/multi/mmdoc_search.*.js
  mkdir "$out"
  cp -r manual/single manual/multi "$out/"
''
