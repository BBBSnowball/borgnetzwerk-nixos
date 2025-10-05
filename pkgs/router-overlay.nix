final: prev: {
  #router = prev.router.overrideAttrs (_: {
  #  # disable tests because they hang forever
  #  doCheck = false;
  #});

  router = prev.router.override (orig:
  let
    changes = rec {
      # router in NixOS is too old ("serde_v8 error: invalid type" in worker)
      # -> use the same version that rover would download
      version = "1.61.10";

      src = final.fetchFromGitHub {
        owner = "apollographql";
        repo = "router";
        rev = "v${version}";
        hash = "sha256-djL6iRYBjzrJOwCFTrQTThcI7wAikEREU/SW1Ak0m+w=";
      };
    
      cargoHash = "sha256-dVsR7I72Agn5Jf8hBwo0piBPmjySYpgU5GS3gn9pzPg=";
  
      # disable tests because they hang forever
      doCheck = false;
    };
  in {
    # We have to override the arguments of buildRustPackage but there is no builtin support for this.
    rustPlatform = orig // { buildRustPackage = args: orig.rustPlatform.buildRustPackage (args // changes); };
  });
}
