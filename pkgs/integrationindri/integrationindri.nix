{
  src,
  python,
  stdenv,
  callPackage,
  mkShell,
  writeShellScript,
  buildPythonPackage,
  setuptools,
}:
let
  packageOverrides = callPackage ./python-packages.nix { };
  packageOverrides2 = final: prev: prev // {
    libcst = python.pkgs.libcst;  # needs Rust dependencies
    PyYAML = python.pkgs.pyyaml;  # avoid clashing files because libcst also uses this
  };
  python' = python.override { packageOverrides = final: prev: packageOverrides2 final (packageOverrides final prev); };
  getAllPkgs = ps:
    map (name: ps.${name}) (builtins.attrNames (packageOverrides ps ps))
    ++ [ ps.setuptools-rust ];
  pythonWithPackages = python'.withPackages getAllPkgs;
  shell = mkShell {
    nativeBuildInputs = [ pythonWithPackages ];
  };
in
buildPythonPackage {
  pname = "integrationindri";
  version = "0-unstable-${src.lastModifiedDate}-${src.shortRev}";
  inherit src;

  patches = [
    ./01-datadir.patch
  ];

  postPatch = ''
    cp ${./setup.py} setup.py
    cp ${./integrationindri.py} pythonServer/integrationindri.py
    touch pythonServer/__init__.py
  '';

  outputs = [ "out" "graphql" ];

  dependencies = getAllPkgs python'.pkgs;
  #nativeBuildInputs = [ python'.pkgs.strawberry-graphql ];

  build-system = [ setuptools ];

  postBuild = ''
    PYTHONPATH=pythonServer ${pythonWithPackages}/bin/strawberry export-schema api.schema >schema.graphql
  '';

  postInstall = ''
    mkdir $graphql
    cp schema.graphql $graphql/
  '';

  passthru = {
    inherit packageOverrides pythonWithPackages shell;
    python = python';
  };
}
