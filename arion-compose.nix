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
          };
        };
      };
    };
  };
}
