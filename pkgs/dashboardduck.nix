# see https://nixos.org/manual/nixpkgs/stable/#javascript-pnpm
{
  src,
  lib,
  stdenv,
  nodejs,
  pnpm_10,
  imagemagick,
  overrideOAuthUrl ? null,
}:
let
  pnpm = pnpm_10;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dashboardduck";
  version = "0-unstable-${src.lastModifiedDate}-${src.shortRev}";
  inherit src;

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
    imagemagick
  ];

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-5xe0WYOJmHttD0R9jZwMo1grXv5szf0wRgAZfnwf8T0=";
  };

  inherit overrideOAuthUrl;
  postPatch = lib.optionalString (overrideOAuthUrl != null) ''
    substituteInPlace \
      src/pages/integrationpage/integrationContent/MirahezeCard.tsx \
      src/pages/integrationpage/integrationContent/WikibaseCard.tsx \
      --replace-fail 'https://preferably-valid-ibex.ngrok-free.app' "$overrideOAuthUrl"
  '';

  buildPhase = ''
    pnpm codegen  # updates src/__generated__/
    pnpm build
  '';

  outputs = [ "out" "graphql" "favicon" ];

  installPhase = ''
    cp -r dist $out
    cp -r graphql_federation $graphql

    mkdir $favicon
    magick src/assets/1_1_transparent.png -resize 16x16 $favicon/favicon.ico
  '';
})
