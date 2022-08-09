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
      terraform = pkgs.terraform.withPlugins
        (p: [ p.null p.external p.libvirt p.google p.azurerm ]);

      genConfig = env:
        terranix.lib.terranixConfiguration {
          inherit system pkgs;
          modules = [ ./provision ./env/${env}/config.nix ];
        };

      localConfig = genConfig "local";
      gcpConfig = genConfig "gcp";
    in {
      # overlay
      overlays = import ./overlays;
      # Packages
      packages.${system} = {
        devShell = import ./devShell.nix ({ inherit pkgs system; } // inputs);
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
        # defaults to local
        apply = self.apps.${system}.apply-local;

        # nix run ".#apply-local"
        apply-local = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply-local" ''
            scripts/terranix-apply.sh "local" ${localConfig}
          '');
        };

        # nix run ".#apply-gcp"
        apply-gcp = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply-gcp" ''
            scripts/terranix-apply.sh "gcp" ${gcpConfig}
          '');
        };

        # nix run ".#local-vault"
        local-vault = {
          type = "app";
          program = toString (pkgs.writers.writeBash "local-vault" ''
            set -euo pipefail
            cd arion/
            arion up
          '');
        };

        # nix run ".#local-k8s"
        local-k8s = {
          type = "app";
          program = toString (pkgs.writers.writeBash "local-k8s" ''
            set -euo pipefail
            scripts/k8s/local-k8s.sh
            scripts/k8s/configre.sh
          '');
        };

        # nix run ".#destroy"
        # defaults to local
        destroy = self.apps.${system}.destroy-local;

        # nix run ".#destroy-local"
        destroy-local = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy-local" ''
            scripts/terranix-destroy.sh "local" ${localConfig}
          '');
        };

        # nix run ".#destroy-gcp
        destroy-gcp = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy-gcp" ''
            scripts/terranix-destroy.sh "gcp" ${gcpConfig}
          '');
        };

        # nix run ".#clean-ssh"
        clean-ssh = {
          type = "app";
          program = toString (pkgs.writers.writeBash "clean-ssh" ''
            set -euo pipefail
            for ip in $(${pkgs.jq}/bin/jq -r '.[].value.ip.pub' ./env/*/output.json); do
              ssh-keygen -R "$ip"
            done
          '');
        };
        # nix run ".#deploy"
        deploy = {
          type = "app";
          program = toString (pkgs.writers.writeBash "deploy" ''
            set -euo pipefail
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
        keys = import ./keys; # datacenter: {...}
        genOutput = env:
          let output = fromJSON (readFile ./env/${env}/output.json);
          in foldl' (a: b: a // b) { } (map (name:
            let host = output.${name}.value;
            in {
              # generate hosts by name prefix
              ${name} = {
                deployment = {
                  tags = [ env ];
                  targetHost = host.ip.pub;
                  keys = import ./keys;
                };
              };
            }) (attrNames output));
      in {
        meta = { nixpkgs = pkgs; };
        defaults = import ./deploys/consul;
      } // (genOutput "local") // (genOutput "gcp");
    };
}
