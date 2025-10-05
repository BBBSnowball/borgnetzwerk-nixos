{
  src,
  python3,
  stdenv,
  callPackage,
  mkShell,
  writeShellScript,
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
in
stdenv.mkDerivation {
  pname = "integrationindri";
  version = "0-unstable-${src.lastModifiedDate}-${src.shortRev}";
  inherit src;

  patches = [
    ./integrationindri--01-datadir.patch
  ];

  outputs = [ "out" "graphql" ];

  startScript = writeShellScript "integrationindri" ''
    export PYTHONPATH=@out@/share/integrationindri
    ${pythonWithPackages}/bin/python -m flask --app server run
  '';

  buildPhase = ''
    PYTHONPATH=pythonServer ${pythonWithPackages}/bin/strawberry export-schema api.schema >schema.graphql
  '';

  installPhase = ''
    mkdir -p $out/{bin,share}
    substitute $startScript $out/bin/integrationindri --replace @out@ $out
    chmod +x $out/bin/integrationindri
    cp -r pythonServer $out/share/integrationindri

    mkdir $graphql
    cp schema.graphql $graphql/
  '';

  passthru = {
    inherit packageOverrides python pythonWithPackages shell;
  };
}
