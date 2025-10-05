{
  src,
  python3,
  stdenv,
  callPackage,
  mkShell,
  writeShellScriptBin,
}:
let
  packageOverrides = callPackage ./integrationindri-python-packages.nix { };
  packageOverrides2 = final: prev: prev // {
    libcst = python3.pkgs.libcst;  # needs Rust dependencies
    PyYAML = python3.pkgs.pyyaml;  # avoid clashing files because libcst also uses this
  };
  python = python3.override { packageOverrides = final: prev: packageOverrides2 final (packageOverrides final prev); };
  getAllPkgs = ps:
    map (name: ps.${name}) (builtins.attrNames (packageOverrides ps ps))
    ++ [ ps.setuptools-rust ];
  pythonWithPackages = python.withPackages getAllPkgs;
  shell = mkShell {
    nativeBuildInputs = [ pythonWithPackages ];
  };

  pname = "integrationindri";
  version = "0-unstable-${src.lastModifiedDate}-${src.shortRev}";
in
writeShellScriptBin "integrationindri" ''
  export PYTHONPATH=${src}/pythonServer
  ${pythonWithPackages}/bin/python -m flask --app server run
'' // {
  inherit pname version src;
  inherit packageOverrides python pythonWithPackages shell;
}
