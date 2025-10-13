{
  description = "Software for WissKommWiki, 'A digital knowledge infrastructure to provide information on scientific videos and podcasts'";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    systems.url = "github:nix-systems/default-linux";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    pip2nix.url = "github:nix-community/pip2nix";
    #pip2nix.inputs.nixpkgs.follows = "nixpkgs";

    src-dashboardduck.url = "github:xEatos/dashboardduck/main";
    src-dashboardduck.flake = false;
    src-searchsnail.url = "github:xEatos/searchsnail";
    src-searchsnail.flake = false;
    src-integrationindri.url = "github:xEatos/integrationindri";
    src-integrationindri.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, pip2nix, src-dashboardduck, src-searchsnail, src-integrationindri, ... }:
  let
    lib = nixpkgs.lib;

    # eachDefaultSystemPassThrough won't work here because it doesn't merge nixosConfigurations
    # from multiple systems, i.e. we would only get the ones for the last system.
    postprocess = prev:
    let
      foldSystemIntoNames = lib.concatMapAttrs (system: entries:
        lib.mapAttrs' (name: value: {
          name = "${name}-${system}";
          value = value;
        }) entries);
    in prev // { nixosConfigurations = foldSystemIntoNames prev.nixosConfigurations; };

    eachDefaultSystemSmart = f: postprocess (flake-utils.lib.eachDefaultSystem (system: f {
      inherit system;
      pkgs = nixpkgs.legacyPackages.${system};
    }));
  in
    eachDefaultSystemSmart ({ system, pkgs }: rec {
      packages = rec {
        dashboardduck = pkgs.callPackage ./pkgs/dashboardduck/dashboardduck.nix { src = src-dashboardduck; };
        searchsnail = pkgs.callPackage ./pkgs/searchsnail/searchsnail.nix { src = src-searchsnail; };
        integrationindri = pkgs.python3Packages.callPackage ./pkgs/integrationindri/integrationindri.nix { src = src-integrationindri; };
        rover-config = pkgs.callPackage ./pkgs/rover/rover-config.nix { inherit packages; };

        #pip2nix = let
        #  make-pip2nix = {pythonVersion}: {
        #    name = "python${pythonVersion}";
        #    value = import inputs.pip2nix {
        #      inherit pkgs;
        #      pythonPackages = "python${pythonVersion}Packages";
        #    };
        #  };
        #  shortVersion = builtins.replaceStrings [ "." ] [ "" ] pkgs.python3.pythonVersion;
        #in (make-pip2nix { pythonVersion = shortVersion; });
        pip2nix = inputs.pip2nix.packages.${system}.default;

        # rover downloads additional components to $HOME
        rover = pkgs.buildFHSEnv {
          name = "rover";
          targetPkgs = pkgs: (with pkgs; [
            pkgs.rover
          ]);
          runScript = "rover";
        };
      };

      apps = rec {
        #hello = flake-utils.lib.mkApp { drv = self.packages.${system}.hello; };

        updateSearchsnailDeps = {
          type = "app";
          program = packages.searchsnail.mitmCache.updateScript.outPath;
          meta.description = ''update cached dependencies for searchsnail (fetchGradle / mitmCache)'';
        };

        pip2nix = {
          type = "app";
          program = "${packages.pip2nix}/bin/pip2nix";
          meta.description = ''run pip2nix'';
        };

        updateIntegrationindriDeps = {
          type = "app";
          program = builtins.toString (pkgs.writeShellScript "update" ''
            #nix run github:nix-community/pip2nix -- generate -r requirements.txt
            ${packages.pip2nix}/bin/pip2nix generate \
              -r ${src-integrationindri}/pythonServer/requirements.txt \
              --output pkgs/integrationindri/python-packages.nix \
              "$@"
          '');
          meta.description = ''update cached dependencies for integrationindri (pip2nix)'';
        };
      };

      nixosConfigurations.dev = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./systems/dev.nix
          ({
            _module.args = {
              packages = self.packages.${system};
              inherit nixpkgs;
            };
          })
        ];
      };
    });
}
