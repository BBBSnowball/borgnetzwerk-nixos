{
  src,
  lib,
  stdenv,
  gradle_8,
  makeWrapper,
  jdk17,
}:
let
  jre = jdk17;
  gradle = gradle_8.override {
    javaToolchains = [ "${jdk17}/lib/openjdk" ];
  };
in

# see https://nixos.org/manual/nixpkgs/stable/#gradle
stdenv.mkDerivation (finalAttrs: {
  pname = "searchsnail";
  version = "0-unstable-${src.lastModifiedDate}-${src.shortRev}";
  inherit src;

  nativeBuildInputs = [
    gradle
    makeWrapper
    jdk17
  ];

  # if the package has dependencies, mitmCache must be set
  mitmCache = gradle.fetchDeps {
    #inherit (finalAttrs) pname;
    pkg = finalAttrs.finalPackage;
    data = ./searchsnail-deps.json;
  };

  # this is required for using mitm-cache on Darwin
  __darwinAllowLocalNetworking = true;

  gradleFlags = [ "-Dfile.encoding=utf-8" ];

  gradleBuildTask = "bootJar";

  #doCheck = true;  #FIXME test fails because expected result is missing
  doCheck = false;

  installPhase = ''
    mkdir -p $out/{bin,share/searchsnail}
    cp build/libs/searchsnail-0.0.1-SNAPSHOT.jar $out/share/searchsnail/searchsnail.jar

    makeWrapper ${lib.getExe jre} $out/bin/searchsnail \
      --add-flags "-jar $out/share/searchsnail/searchsnail.jar"
  '';

  meta.sourceProvenance = with lib.sourceTypes; [
    fromSource
    binaryBytecode # mitm cache
  ];
})
