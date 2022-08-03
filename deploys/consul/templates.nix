{ config, pkgs, ... }:
with pkgs.lib.types;
let
  inherit (pkgs) lib;
  inherit (builtins) getEnv length;
  inherit (lib) mkIf mkOption attrNames foldl';
  inherit (lib.opt) mk' mkBool';
  ctemplateModule = submodule ({ config, name, ... }: {
    options = {
      package =
        mk' package pkgs.consul-template "Which consul-template pkg is used";
      consulPackage = mk' package pkgs.consul "Which consul pkg is used";
      user = mk' str "consul" "user used by service";
      path = mk' str "/etc/consul.d/ctemplate.output" "path linked in path";
      text = mk' str "" "template used by service; used for script and path";
      templates = mk' (attrsOf templateModule) { }
        "templates used by service; used for script and config";
      config = mk' str "" "config used by templates";
      script = mk' str "" "reload script used by service";
      vault-addr = mk' str (getEnv "VAULT_ADDR") "vault addr";
      vault-token = mk' str (getEnv "VAULT_TOKEN") "vault token";
    };
  });
  templateModule = submodule ({ config, name, ... }: {
    options = {
      user = mk' str "consul" "user used by service";
      mode = mk' str "0440" "mode used in file";
      text = mk' str "" "template in text format";
    };
  });

in {
  options = {
    services.consul-templates = mkOption {
      type = (attrsOf ctemplateModule);
      default = { };
      description = "Consul template options";
    };
  };
  config = let cfg = config.services.consul-templates;
  in {
    environment.etc = foldl' (a: b: a // b) { } (map (name:
      let
        cfg_name = cfg.${name};
        isTemplates = (length (attrNames cfg_name.templates)) > 0;
      in {
        "consul.d/sh.d/reload-${name}.sh" = {
          inherit (cfg_name) user;
          mode = "0540";
          text = ''
            #!/bin/sh
            ${cfg_name.script}
          '';
        };
      } // (if cfg_name.config != "" then {
        "consul.d/hcl.d/${name}.hcl" = {
          inherit (cfg_name) user;
          mode = "0440";
          text = cfg_name.config;
        };
      } else
        { }) // (if (cfg_name.text != "") then {
          "consul.d/tpl.d/${name}.tpl" = {
            inherit (cfg_name) user;
            mode = "0440";
            text = cfg_name.text;
          };
        } else
          foldl' (a: b: a // b) { } (map (tname: {
            "consul.d/tpl.d/${tname}.tpl" = {
              inherit (cfg_name.templates.${tname}) user;
              mode = cfg_name.templates.${tname}.mode;
              text = cfg_name.templates.${tname}.text;
            };
          }) (attrNames cfg_name.templates))))
      (attrNames config.services.consul-templates));

    systemd.services = foldl' (a: b: a // b) { } (map (name:
      let cfg_name = cfg.${name};
      in {
        "ctemplate-${name}" = {
          description = "Consul-Template configuration for ${name}.";
          documentation = [ "https://github.com/hashicorp/consul-template" ];
          restartIfChanged = true;
          wantedBy = [ "multi-user.target" "consul.service" ];
          requires = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [ cfg_name.package cfg_name.consulPackage ];
          serviceConfig = {
            ExecStart = if cfg_name.text != "" then ''
              ${cfg_name.package}/bin/consul-template \
                -template "/etc/consul.d/tpl.d/${name}.tpl:${cfg_name.path}:/etc/consul.d/sh.d/reload-${name}.sh" \
                -vault-addr=${cfg_name.vault-addr} \
                -vault-token=${cfg_name.vault-token}'' else ''
                ${cfg_name.package}/bin/consul-template \
                  -config "/etc/consul.d/hcl.d/${name}.hcl" \
                  -vault-addr=${cfg_name.vault-addr} \
                  -vault-token=${cfg_name.vault-token}'';
            ExecReload = "/etc/consul.d/sh.d/reload-${name}.sh";
            KillMode = "process";
            KillSignal = "SIGINT";
            LimitNOFILE = "infinity";
            LimitNPROC = "infinity";
            Restart = "on-failure";
            RestartSec = "2";
            TasksMax = "infinity";
            User = cfg_name.user;
          };
          unitConfig = {
            StartLimitBurst = "3";
            StartLimitIntervalSec = "10";
          };
        };
      }) (attrNames config.services.consul-templates));
  };
}
