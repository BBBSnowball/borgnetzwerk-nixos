{ lib, pkgs, config, packages, nixpkgs, ... }:
let
  # slow build but more suitable for production use
  useRouter = true;
in
{
  networking.hostName = "borgnetzwerk-dev";
  boot.isContainer = true;
  networking.firewall.enable = false;
  networking.useDHCP = false;

  system.stateVersion = "25.05";  # don't change without reading the documentation

  environment.systemPackages = with pkgs; [
    #rover
    packages.rover
    ngrok
    vim
  ] ++ lib.optionals useRouter [ router ];

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.registry.nixpkgs = { flake = nixpkgs; };
  environment.etc.current-nixpkgs.source = nixpkgs;
  nix.nixPath = [
    "nixpkgs=/etc/current-nixpkgs"
    # keep the other default values
    "nixos-config=/etc/nixos/configuration.nix"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  services.nginx = {
    enable = true;

    virtualHosts.localhost = {
      root = packages.dashboardduck.out;
      listen = [ {
        addr = "127.0.0.1";
        port = 8000;
      } ];

      locations."/favicon.ico".root = packages.dashboardduck.favicon;
      locations."= /oauthDomain.txt".alias = "/run/credentials/nginx.service/domain";

      # single-page application rewrites the URL but would fail on reload
      # so we have to fallback to /index.html.
      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
      };
      # ... but not for static files
      locations."/static/" = {
        tryFiles = "$uri =404";
      };
    };

    virtualHosts.integrationindri = {
      listen = [ {
        addr = "127.0.0.1";
        port = 5000;
      } ];

      locations."/".extraConfig = ''
        uwsgi_pass unix://${config.services.uwsgi.runDir}/integrationindri/uwsgi.sock;
        include ${pkgs.nginx}/conf/uwsgi_params;
      '';
    };
  };
  systemd.services.nginx.serviceConfig = {
    LoadCredential = [
      # https://your-domain.ngrok-free.dev  (no trailing slash)
      "domain:/root/ngrok-domain.txt"
    ];
    # provide default to make missing file for LoadCredential not fatal
    SetCredential = [ "domain:https://invalid" ];
  };

  systemd.services.searchsnail = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = ''${packages.searchsnail}/bin/searchsnail'';
    serviceConfig.DynamicUser = true;
  };

  #systemd.services.integrationindri = {
  #  after = [ "network.target" ];
  #  wantedBy = [ "multi-user.target" ];

  #  environment.DATADIR = "/var/lib/integrationindri";
  #  serviceConfig = {
  #    ExecStart = ''${packages.integrationindri}/bin/integrationindri'';
  #    DynamicUser = true;
  #    StateDirectory = "integrationindri";
  #  };
  #};

  services.uwsgi = {
    enable = true;
    plugins = [ "python3" ];
    instance = {
      type = "normal";
      pythonPackages = _: [ packages.integrationindri ];
      module = "server:app";
      env = [
        "DATADIR=/var/lib/integrationindri"
      ];

      socket = "${config.services.uwsgi.runDir}/integrationindri/uwsgi.sock";
      #socketGroup = "nginx";
      #immediate-gid = "nginx";
      chmod-socket = "777";
    };
  };
  systemd.services.uwsgi = {
    serviceConfig.StateDirectory = "integrationindri";
    aliases = [ "integrationindri.service" ];
    serviceConfig.ExecStartPre = "!${pkgs.coreutils}/bin/install -d ${config.services.uwsgi.runDir}/integrationindri -m 0750 -o uwsgi -g nginx";
  };

  systemd.services.ngrok = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.ConditionPathExists = [
      "/root/.config/ngrok/ngrok.yml"
      "/root/ngrok-domain.txt"
    ];

    script = ''
      exec ${pkgs.ngrok}/bin/ngrok http \
        --url="$(cat $CREDENTIALS_DIRECTORY/domain)" \
        --config=$CREDENTIALS_DIRECTORY/authtoken.yml \
        http://127.0.0.1:5000
    '';

    serviceConfig = {
      DynamicUser = true;
      #StateDirectory = "ngrok";

      LoadCredential = [
        # create this file with: ngrok config add-authtoken ...
        "authtoken.yml:/root/.config/ngrok/ngrok.yml"
        # https://your-domain.ngrok-free.dev  (no trailing slash)
        "domain:/root/ngrok-domain.txt"
      ];
      # provide default to make missing file for LoadCredential not fatal
      SetCredential = [ "authtoken.yml:1" "domain:https://invalid" ];
    };
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    #FIXME Elastic License v2 is probably fine but we should check!
    #  see https://www.apollographql.com/trust/licensing
    "router"
    #FIXME unfree license!
    "ngrok"
  ];

  nixpkgs.overlays = [
    (import ../pkgs/rover/router-overlay.nix)
  ];

  users.users.rover.isSystemUser = true;
  users.users.rover.group = "rover";
  users.groups.rover = {};

  systemd.services.rover = let
    config = packages.rover-config;
    rover = packages.rover;
  in {
    after = [ "network.target" "searchsnail.service" "integrationindri.service" ];
    wantedBy = [ "multi-user.target" ];
    # restart rover if these services restart because rover will fetch their graph config on start
    bindsTo = [ "searchsnail.service" "integrationindri.service" ];

    path = [ rover ] ++ lib.optionals useRouter [ pkgs.router ];
    environment.CONFIG = config;
    serviceConfig.StateDirectory = "rover";

    # rover will download and run binaries so we cannot have its home dir mounted with noexec.
    #serviceConfig.DynamicUser = true;
    serviceConfig.User = "rover";

    script = ''
      cd /var/lib/rover
      mkdir -p config home
      export HOME=$PWD/home
      cd config
      cp ${config}/* .
      chmod -R u+w .

      rover supergraph compose --config ./supergraph_config.yaml --output ./supergraph.graphql

    '' + (if useRouter then ''
      exec router --supergraph ./supergraph.graphql --config ./router_config.yaml \
        --anonymous-telemetry-disabled --listen 127.0.0.1:4000
      #--log trace --dev
    '' else ''
      exec rover dev --supergraph-config ./supergraph_config.yaml --polling-interval 10 \
        --elv2-license accept --router-config ./router_config.yaml
      #--log debug
    '');
  };
}
