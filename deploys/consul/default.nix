{ name, nodes, pkgs, config, ... }:
let
  inherit (builtins) fromJSON readFile attrNames attrValues length;
  inherit (pkgs.lib) concatMapStrings mkIf strings filter;
  ports = {
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
  k = k: k.text;
in {
  imports = [ ../../generators/minimal-libvirt.nix ./gateway.nix ];
  networking.hostName = name;
  networking.extraHosts = concatMapStrings (hostName: ''
    ${nodes.${hostName}.config.deployment.targetHost} ${hostName}
  '') (attrNames nodes);

  # use xlbs to build envoyPackage
  environment.noXlibs = false;

  environment.systemPackages = with pkgs; [ jq envoy ];
  deployment = {
    tags = [ "consul" "server" "replica" ];
    targetUser = "main";
    targetPort = 22;
  };
  # TODO: fix rules
  networking.firewall.enable = false;

  services.consul = with keys; {
    enable = true;
    leaveOnStop = true;
    extraConfig = let
      filterHostsBy = datacenter:
        map (nodeName: nodes.${nodeName}.config.deployment.targetHost)
        (filter (a: (strings.hasPrefix datacenter a)) (attrNames nodes));
      primary_hosts = filterHostsBy (k primary_datacenter);
      hosts = filterHostsBy (k datacenter);
      isPrimary = (k primary_datacenter != k datacenter);
    in {
      ui_config = { enabled = true; };
      domain = k domain;
      datacenter = k datacenter;
      primary_datacenter = (k primary_datacenter);
      server = true;
      retry_join = hosts;
      bind_addr = "0.0.0.0";
      client_addr = "0.0.0.0";
      recursors = [ "1.1.1.1" "8.8.8.8" ];
      bootstrap_expect = length hosts;
      advertise_addr = config.deployment.targetHost;
      advertise_addr_wan = config.deployment.targetHost;
      log_level = "DEBUG";
      node_name = name;
      connect = {
        enabled = true;
        enable_mesh_gateway_wan_federation = true;
      };
      ports = { inherit (ports) grpc; };
      addresses.grpc = "127.0.0.1";
      primary_gateways =
        mkIf isPrimary (map (h: "${h}:${toString ports.mesh}") primary_hosts);
    };
  };

  services.consul-gateway = {
    enable = true;
    logLevel = "debug";
  };
}
