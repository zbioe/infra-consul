{ config, pkgs, ... }:
let
  inherit (pkgs) lib;
  inherit (lib) mkIf mkOption;
  inherit (lib.opt) mk' mkBool';
in {
  options = with lib.types; {
    services.consul-gateway = {
      enable = mkBool' false "Enable Consul Mesh";
      package = mk' package pkgs.consul "Which Consul package to use";
      envoyPackage = mk' package pkgs.envoy "Which Envoy package to use";
      logLevel = mk' str "debug" "Which Envoy package to use";
      user = mk' str "consul" "user used by systemd";
    };
  };
  config = let
    inherit (builtins) attrNames foldl';
    cfg = config.services.consul-gateway;
  in {
    systemd = mkIf cfg.enable {
      services = {
        consul-gateway = {
          description = "Consul Gateway";
          path = [ cfg.package cfg.envoyPackage ];
          wantedBy = [ "multi-user.target" ];
          after = [ "consul.service" ];
          script = ''
            ${pkgs.consul}/bin/consul connect envoy \
              -gateway=mesh \
              -register \
              -envoy-version ${cfg.envoyPackage.version} \
              -expose-servers \
              -- --log-level ${cfg.logLevel}
          '';
          serviceConfig = {
            Restart = "always";
            RestartSec = "2";
            User = cfg.user;
            TasksMax = "infinity";
          };
        };
      };
    };
  };
}
