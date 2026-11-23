# Resolve project-local settings before drvkit filters sources and selects a target.
{ lib, projectSource, legacyPackages }:
args:
let
  src = args.src or args.root or null;
  manifest = src + "/drvlang.json";
  hasManifest = src != null && !lib.isDerivation src && builtins.pathExists manifest;
  manifestData = if hasManifest then builtins.fromJSON (builtins.readFile manifest) else {};
  config = manifestData.drvc or {};
  pkgs = legacyPackages.${args.system};
  packages = field: map (name: pkgs.${name} or (throw "drvc: unknown Nixpkgs package '${name}' in ${field}")) (config.${field} or []);
  rootPath = if builtins.isPath src then src else /. + builtins.unsafeDiscardStringContext (toString src);
  pathFor = file:
    if !builtins.isString file || lib.any (part: builtins.elem part [ "" "." ".." ]) (lib.splitString "/" file)
    then throw "drvc: expected a project-relative path in files, got ${builtins.toJSON file}"
    else rootPath + "/${file}";
  target = args.target or "";
  targetFiles = config.targetFiles or {};
  commands = args.commands or manifestData.commands or {};
  matchingTargets = lib.filterAttrs (name: path: name == target || path == target) commands;
  files = if !(config ? files) && targetFiles == {} then null else
    (config.files or []) ++ lib.concatLists (builtins.attrValues (
      if target == "" || target == null then targetFiles
      else builtins.intersectAttrs matchingTargets targetFiles));
  selectFiles = files != null && !(args ? srcForTarget) && !(src ? _isLibCleanSourceWith);
  defaults = lib.optionalAttrs (manifestData ? commands) { inherit (manifestData) commands; }
    // lib.optionalAttrs (config ? program) { inherit (config) program; };
in assert lib.assertMsg (!(args ? root && args ? src)) "drvc: supply either root or src";
   assert lib.assertMsg (!(args ? root) || files != null) "drvc: root requires drvc.files in drvlang.json";
   assert lib.assertMsg (builtins.isAttrs config &&
     lib.subtractLists [ "files" "targetFiles" "libraries" "tools" "program" ] (builtins.attrNames config) == [])
     "drvc: unknown field in the drvc section of drvlang.json";
   defaults // removeAttrs args [ "root" ] // lib.optionalAttrs (src != null) {
     src = if selectFiles then projectSource { root = rootPath; files = map pathFor files; } else src;
   } // {
     buildInputs = packages "libraries" ++ (args.buildInputs or []);
     nativeBuildInputs = packages "tools" ++ (args.nativeBuildInputs or []);
   }
