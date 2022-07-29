{ name, nodes, pkgs, config, ... }:
let
  inherit (builtins) fromJSON readFile;
  defaultPorts = {
    admin = 19000;
    mesh = 8443; # gateway
    dns = 8600; # tcp and udp, to add it in resolv.conf, bind it to 53
    http = 8500; # tcp
    https = 8501; # tcp
    grpc = 8502; # tcp
    server = 8300; # tcp
    serf_lan = 8301; # tcp and udp
    serf_wan = 8302; # tcp and udp
    sidecar = {
      from = 21000;
      to = 21255;
    };
    expose = {
      from = 21500;
      to = 21755;
    };
  };
  keys = config.deployment.keys;
in {
  imports = [ ../../generators/minimal-libvirt.nix ];
  networking.hostName = name;
  environment.systemPackages = with pkgs; [ jq ];
  deployment = {
    tags = [ "consul" "server" "replica" ];
    targetUser = "main";
    targetPort = 22;
  };

  services.consul = {
    enable = true;
    leaveOnStop = true;
    extraConfig = { domain = keys.domain.text; };
  };
}
