{ pkgs, ... }: {
  config = {
    services = {
      vault = { config, pkgs, ... }: {
        service = {
          image = "vault:latest";
          ports = [ "8200:8200" ];
          environment = {
            VAULT_ADDR = "0.0.0.0";
            VAULT_DEV_ROOT_TOKEN_ID = "root-token";
            VAULT_LOG_LEVEL = "trace";
          };
        };
      };
      vault-setup = { config, pkgs, ... }: {
        service = {
          image = "vault:latest";
          depends_on = [ "vault" ];
          volumes = [ "../scripts/vault-init.sh:/init.sh" ];
          entrypoint = "/init.sh";
          environment = {
            VAULT_ADDR = "http://vault:8200";
            VAULT_TOKEN = "root-token";
          };
        };
      };
    };
  };
}
