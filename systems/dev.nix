{ pkgs, packages, ... }:
{
  networking.hostName = "borgnetzwerk-dev";
  boot.isContainer = true;
  networking.firewall.enable = false;
  networking.useDHCP = false;

  system.stateVersion = "25.05";  # don't change without reading the documentation

  environment.systemPackages = with pkgs; [
    rover
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
    };
  };

  systemd.services.searchsnail = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = ''${packages.searchsnail}/bin/searchsnail'';
  };

  systemd.services.integrationindri = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = ''${packages.integrationindri}/bin/integrationindri'';
  };

  systemd.services.rover = let
    config = packages.dashboardduck.graphql;
  in {
    after = [ "network.target" "searchsnail.service" "integrationindri.service" ];
    wantedBy = [ "multi-user.target" ];
    # restart rover if these services restart because rover will fetch their graph config on start
    bindsTo = [ "searchsnail.service" "integrationindri.service" ];

    path = with pkgs; [ rover ];
    environment.CONFIG = config;
    #FIXME don't use rover in dev mode!
    serviceConfig.ExecStart = ''
      ${pkgs.rover}/bin/rover dev --supergraph-config ${config}/supergraph_config.yaml --polling-interval 10 --elv2-license accept
    '';
  };
}
