{ self, system, pkgs }:
let
  upstream = builtins.fetchTree {
    type = "github"; owner = "ryantm"; repo = "mmdoc";
    rev = "684ba64be908128d2092dfd13675397d4272b349"; # 0.27.0 with portable EOF checks
    narHash = "sha256-m7Hlow2fG5EH/IGjxgGQ9yslFbLlesOb5yIExoNqPss=";
  };
  root = /. + builtins.unsafeDiscardStringContext upstream.outPath;
  mmdoc = self.lib.mkPackage { inherit system root; };
in pkgs.runCommand "drvc-mmdoc-manual" { __contentAddressed = true; } ''
  ${mmdoc}/bin/mmdoc mmdoc ${root + "/doc"} manual
  grep -Fq 'Minimal Markdown Documentation' manual/single/index.html
  grep -Fq 'contributing/' manual/multi/index.html
  test -s manual/multi/contributing/index.html
  test -s manual/multi/mmdoc_search.*.js
  mkdir "$out"
  cp -r manual/single manual/multi "$out/"
''
