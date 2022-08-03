{
  description = "Consul Deploy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/9370544d849b";
    # terraform module
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # generate imgs
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, terranix, nixos-generators, ... }@inputs:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
      system = "x86_64-linux";
      terraform =
        pkgs.terraform.withPlugins (p: [ p.null p.external p.libvirt ]);
      terraformConfiguration = terranix.lib.terranixConfiguration {
        inherit system pkgs;
        modules = [ ./provision.nix ];
      };
    in {
      # overlay
      overlays = import ./overlays;
      # Packages
      packages.${system} = {
        devShell =
          import ./devShell.nix ({ inherit pkgs nixpkgs system; } // inputs);
        qcow = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [
            # minimal libvirt qcow
            ./generators/minimal-libvirt.nix
          ];
          format = "qcow";
        };
      };
      devShells.${system}.default = self.packages.${system}.devShell;

      # Apps
      apps.${system} = {
        # nix run ".#apply"
        apply = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply" ''
            set -euo pipefail
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${terraformConfiguration} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform apply \
              && ${terraform}/bin/terraform output -json > output.json
          '');
        };
        # nix run ".#local-vault"
        local-vault = {
          type = "app";
          program = toString (pkgs.writers.writeBash "local-vault" ''
            set -euo pipefail

            arion up
          '');
        };

        # nix run ".#local-k8s"
        local-k8s = {
          type = "app";
          program = toString (pkgs.writers.writeBash "local-k8s" ''
            set -euo pipefail
            scripts/local-k8s.sh
          '');
        };

        # nix run ".#destroy"
        destroy = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy" ''
            set -euo pipefail
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${terraformConfiguration} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform destroy \
              && rm -f output.json
          '');
        };
        # nix run ".#clean-ssh"
        clean-ssh = {
          type = "app";
          program = toString (pkgs.writers.writeBash "clean-ssh" ''
            set -euo pipefail
            for ip in $(${pkgs.jq}/bin/jq -r '.[].value' output.json); do
              ssh-keygen -R "$ip"
            done
          '');
        };
        # nix run ".#deploy"
        deploy = {
          type = "app";
          program = toString (pkgs.writers.writeBash "deploy" ''
            set -euo pipefail
            [ -f output.json ] || apply
            clean-ssh
            ${pkgs.colmena}/bin/colmena apply
          '');
        };
        # nix run
        default = self.apps.${system}.apply;
      };

      # deploy
      colmena = let
        # read attributes from ouput.json gerated by `nix run .#apply`
        inherit (builtins) fromJSON readFile foldl' attrNames;
        output = fromJSON (readFile ./output.json);
        keys = import ./keys; # datacenter: {...}
      in {
        meta = { nixpkgs = pkgs; };
        defaults = import ./deploys/consul;
      } // foldl' (a: b: a // b) { } (map (name: {
        # generate hosts by name prefix
        ${name} = {
          deployment = {
            targetHost = output.${name}.value;
            keys = import ./keys;
          };
        };
      }) (attrNames output));
    };
}
