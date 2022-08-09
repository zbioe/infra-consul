{ name, nodes, pkgs, config, ... }:
let
  inherit (builtins) attrNames attrValues length match elemAt;
  inherit (pkgs.lib) concatMapStrings mkIf strings filter assertMsg mkForce;
  # inherit (pkgs.lib.asserts) ;
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
  domain = "d";
  primary_datacenter = "c1";
  name_regex = "([a-zA-Z]+[0-9]+)([a-zA-Z]+[0-9]+)";
  name_match = match name_regex name;
  data = assert assertMsg (length name_match == 2) ''
    wrong name format. expect: <datacenter name><number><replica name><number>"
            examples: d12r26, datacenter93replica112, c1r1''; {
      datacenter = elemAt name_match 0;
      replica = elemAt name_match 1;
    };
  variables = {
    VAULT_ADDR = "http://10.0.62.1:8200";
    VAULT_TOKEN = "root-token";
  };
  inherit (data) datacenter replica;
in {
  imports =
    [ ../../generators/minimal-libvirt.nix ./gateway.nix ./templates.nix ];
  networking.hostName = name;
  networking.extraHosts = concatMapStrings (hostName: ''
    ${config.deployment.targetHost} ${hostName}
  '') (attrNames nodes);

  # use xlbs to build envoyPackage
  environment.noXlibs = false;

  environment.systemPackages = with pkgs; [ jq envoy vault openssl ];
  environment.sessionVariables = variables;
  environment = { inherit variables; };
  deployment = {
    tags = [ "consul" "server" datacenter ];
    targetUser = "main";
    targetPort = 22;
  };
  # TODO: fix rules
  networking.firewall.enable = false;

  systemd.services.setup-consul = {
    enable = true;
    script = ''
      mkdir -p /etc/consul.d/pki/{ca,certs}
      chown -R consul:consul /etc/consul.d
    '';
    wantedBy = [
      "ctemplate-pki.service"
      "ctemplate-encryption.service"
      "consul.service"
      "multi-user.target"
    ];
    startLimitBurst = 3;
    serviceConfig = {
      Restart = "no";
      RemainAfterExit = "yes";
      Type = "oneshot";
    };
  };

  systemd.services.consul.serviceConfig = {
    Restart = mkForce "always";
    RestartSec = "2";
  };
  services.consul = {
    enable = true;
    extraConfigFiles = [ "/etc/consul.d/encryption.hcl" ];
    leaveOnStop = true;
    extraConfig = let
      filterHostsBy = datacenter:
        map (nodeName: nodes.${nodeName}.config.deployment.targetHost)
        (filter (a: (strings.hasPrefix datacenter a)) (attrNames nodes));
      primary_hosts = filterHostsBy primary_datacenter;
      hosts = filterHostsBy datacenter;
      isPrimary = primary_datacenter == datacenter;
    in {
      inherit domain datacenter primary_datacenter;
      ui_config = { enabled = true; };
      server = true;
      retry_join = hosts;
      bind_addr = "0.0.0.0";
      client_addr = "0.0.0.0";
      recursors = [ "1.1.1.1" "8.8.8.8" ];
      bootstrap_expect = length hosts;
      advertise_addr = config.deployment.targetHost;
      advertise_addr_wan = config.deployment.targetHost;
      log_level = "DEBUG";
      node_name = replica;
      auto_encrypt = { allow_tls = true; };
      tls = {
        defaults = {
          ca_path = "/etc/consul.d/pki/ca";
          cert_file = "/etc/consul.d/pki/certs/agent.crt";
          key_file = "/etc/consul.d/pki/certs/agent.key";
          verify_outgoing = true;
          verify_incoming = true;
        };
        internal_rpc = { verify_server_hostname = true; };
      };
      connect = {
        enabled = true;
        enable_mesh_gateway_wan_federation = true;
      };
      ports = { inherit (ports) grpc; };
      addresses.grpc = "0.0.0.0";
      primary_gateways = mkIf (!isPrimary)
        (map (h: "${h}:${toString ports.mesh}") primary_hosts);
    };
  };

  services.consul-gateway = {
    enable = true;
    logLevel = "debug";
  };

  services = {
    consul-templates = {
      encryption = {
        wantedBy = [ "consul.service" ];
        path = "/etc/consul.d/encryption.hcl";
        script = ''
          NEW_KEY=$(cut -f2 -d\" </etc/consul.d/gossip.hcl | sed -e '/^$/d')
          consul keyring -install "$NEW_KEY"
          consul keyring -use "$NEW_KEY"
          KEYS=$(curl -s "$CONSUL_HTTP_ADDR/v1/operator/keyring")
          ALL_KEYS=$(echo "''${KEYS}" | jq -r '.[].Keys| to_entries[].key' | sort | uniq)
          for i in ''${ALL_KEYS}; do
            if [ "$i" != "''${NEW_KEY}" ]; then
              consul keyring -remove "$i"
            fi
          done
        '';
        text = ''
          {{ with secret "kv/data/consul/config/encryption" }}
          encrypt = "{{ .Data.data.key}}"
          {{ end }}
        '';
      };
      pki = rec {
        script = "consul reload";
        wantedBy = [ "consul.service" ];
        templates = let
          mkTmpl = field: ''
            {{ with secret "pki_int/issue/${domain}" "common_name=server.${datacenter}.${domain}" "ttl=24h" "alt_names=localhost,${replica}.server.${datacenter}.${domain}" "ip_sans=127.0.0.1,${
              nodes.${name}.config.deployment.targetHost
            }"}}
            {{ .Data.${field} }}
            {{ end }}
          '';
        in {
          "agent.key" = { text = mkTmpl "private_key"; };
          "agent.crt" = { text = mkTmpl "certificate"; };
          "ca.int.crt" = { text = mkTmpl "issuing_ca"; };
          "ca.crt" = {
            text = ''
              {{ with secret "pki/cert/ca" }}
              {{ .Data.certificate }}
              {{ end }}
            '';
          };
        };
        config = ''
          vault {
           unwrap_token = false
           # root-token t false
           renew_token  = false
          }

          consul {
            ssl {
              enabled = false
              verify = false
            }
          }
          template {
            source      = "/etc/consul.d/tpl.d/agent.crt.tpl"
            destination = "/etc/consul.d/pki/certs/agent.crt"
            perms       = 0400
            command     = "/etc/consul.d/sh.d/reload-pki.sh"
          }
          template {
            source      = "/etc/consul.d/tpl.d/agent.key.tpl"
            destination = "/etc/consul.d/pki/certs/agent.key"
            perms       = 0400
            command     = "/etc/consul.d/sh.d/reload-pki.sh"
          }
          template {
            source      = "/etc/consul.d/tpl.d/ca.int.crt.tpl"
            destination = "/etc/consul.d/pki/ca/ca.int.crt"
            perms       = 0400
            command     = "/etc/consul.d/sh.d/reload-pki.sh"
          }
          template {
            source      = "/etc/consul.d/tpl.d/ca.crt.tpl"
            destination = "/etc/consul.d/pki/ca/ca.crt"
            perms       = 0400
            command     = "/etc/consul.d/sh.d/reload-pki.sh"
          }
        '';
      };
    };
  };
}
