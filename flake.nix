{
  description = "Build, test, and run C projects with Meson and dynamic Nix derivations";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/26.05";
    drvkit = { url = "github:drvlang/drvkit"; flake = false; };
    drvcpp.url = "github:drvlang/drvcpp";
    drvcpp.inputs.nixpkgs.follows = "nixpkgs";
    drvcpp.inputs.drvkit.follows = "drvkit";
  };
  outputs = { self, nixpkgs, drvkit, drvcpp }:
    let
      lib = nixpkgs.lib;
      tools = import drvkit {
        inherit self nixpkgs;
        name = "drvc";
        systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
        projectArgs = drvcpp.lib.mesonProjectArgs {
          name = "drvc";
          inherit lib;
          inherit (tools.lib) projectSource;
          inherit (nixpkgs) legacyPackages;
        };
        mkPackage = drvcpp.lib.mesonBuilder { inherit drvkit nixpkgs; name = "drvc"; };
        mkTest = drvcpp.lib.mesonBuilder { inherit drvkit nixpkgs; name = "drvc"; test = true; };
        selectTarget = drvcpp.lib.mesonSelectTarget lib;
        extraChecks = system: let args = { inherit self system; pkgs = nixpkgs.legacyPackages.${system}; }; in {
          benchmark = import ./benchmarks args;
          workspace = import ./tests args;
        };
      };
    in tools // {
      lib = tools.lib // {
        mkMonorepoFlake = args: tools.lib.mkMonorepoFlake (
          lib.optionalAttrs (args ? root && !(args ? commands)) {
            commands = (builtins.fromJSON (builtins.readFile (args.root + "/drvlang.json"))).commands;
          } // args
        );
      };
    };
}
