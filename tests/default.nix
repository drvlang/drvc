{ self, system, pkgs }:
let
  root = ./workspace;
  commands = (builtins.fromJSON (builtins.readFile ./workspace/drvlang.json)).commands;
  srcForTarget = { target, ... }: self.lib.projectSource {
    inherit root;
    files = [ ./workspace/meson.build ./workspace/pkg (root + "/${target}") ];
  };
  workspace = self.lib.mkMonorepoFlake { inherit commands srcForTarget; };
  apps = workspace.apps.${system};
in pkgs.runCommand "drvc-test-workspace" {
  __contentAddressed = true;
  checks = builtins.attrValues workspace.checks.${system};
} ''
  test "$(${apps.api.program} 'two words')" = 'api shared two words'
  test "$(${apps.worker.program} 'two words')" = 'worker shared two words'
  touch "$out"
''
