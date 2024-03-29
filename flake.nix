{
  description = "Consul Deploy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c41b26e688ff";
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

      genConfig = env:
        terranix.lib.terranixConfiguration {
          inherit system pkgs;
          modules = [ ./provision/${env} ./env/${env}/config.nix ];
        };

      libvirtConfig = genConfig "libvirt";
      gcpConfig = genConfig "gcp";
      azureConfig = genConfig "azure";
    in {
      # overlay
      overlays = import ./overlays;
      # Packages
      packages.${system} = {
        devShell = import ./devShell.nix ({ inherit pkgs system; } // inputs);
        # nix build .#qcow
        qcow = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [
            # minimal libvirt
            ./generators/minimal-libvirt.nix
          ];
          format = "qcow";
        };
        # nix build .#gce
        gce = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [
            # minimal gcp
            ./generators/minimal-gcp.nix
          ];
          format = "gce";
        };
        # nix build .#azure
        azure = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [
            # minimal gcp
            ./generators/minimal-azure.nix
          ];
          format = "azure";
        };
      };
      devShells.${system}.default = self.packages.${system}.devShell;

      # Apps
      apps.${system} = {
        # nix run
        default = self.apps.${system}.apply;
        # nix run ".#apply"
        # defaults to libvirt
        apply = self.apps.${system}.apply-libvirt;
        # nix run ".#apply-libvirt"
        apply-libvirt = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply-libvirt" ''
            scripts/terranix-apply.sh "libvirt" ${libvirtConfig}
          '');
        };

        # nix run ".#apply-gcp"
        apply-gcp = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply-gcp" ''
            scripts/terranix-apply.sh "gcp" ${gcpConfig}
          '');
        };
        # nix run ".#apply-azure"
        apply-azure = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply-azure" ''
            scripts/terranix-apply.sh "azure" ${azureConfig}
          '');
        };

        # nix run ".#destroy"
        # defaults to libvirt
        destroy = self.apps.${system}.destroy-libvirt;
        # nix run ".#destroy-libvirt"
        destroy-libvirt = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy-libvirt" ''
            scripts/terranix-destroy.sh "libvirt" ${libvirtConfig}
          '');
        };
        # nix run ".#destroy-gcp
        destroy-gcp = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy-gcp" ''
            scripts/terranix-destroy.sh "gcp" ${gcpConfig}
          '');
        };
        # nix run ".#destroy-azure
        destroy-azure = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy-azure" ''
            scripts/terranix-destroy.sh "azure" ${azureConfig}
          '');
        };

        # nix run ".#clean-ssh"
        # defaults to libvirt
        clean-ssh = self.apps.${system}.clean-ssh-libvirt.program;
        # nix run ".#clean-ssh-libvirt"
        clean-ssh-libvirt = {
          type = "app";
          program = toString (pkgs.writers.writeBash "clean-ssh-libvirt" ''
            ./scripts/clean-ssh.sh libvirt
          '');
        };
        # nix run ".#clean-ssh-gcp"
        clean-ssh-gcp = {
          type = "app";
          program = toString (pkgs.writers.writeBash "clean-ssh-gcp" ''
            ./scripts/clean-ssh.sh gcp
          '');
        };
        # nix run ".#clean-ssh-azure"
        clean-ssh-azure = {
          type = "app";
          program = toString (pkgs.writers.writeBash "clean-ssh-azure" ''
            ./scripts/clean-ssh.sh azure
          '');
        };

        # nix run ".#deploy"
        # defaults to libvirt
        deploy = {
          type = "app";
          program = self.apps.${system}.deploy-libvirt.program;
        };
        # nix run ".#deploy-libvirt"
        deploy-libvirt = {
          type = "app";
          program = toString (pkgs.writers.writeBash "deploy-libvirt" ''
            set -euo pipefail
            ./scripts/clean-ssh.sh libvirt
            ${pkgs.colmena}/bin/colmena apply --on @libvirt
          '');
        };
        # nix run ".#deploy-gcp"
        deploy-gcp = {
          type = "app";
          program = toString (pkgs.writers.writeBash "deploy-gcp" ''
            set -euo pipefail
            ./scripts/clean-ssh.sh gcp
            ${pkgs.colmena}/bin/colmena apply --on @gcp
          '');
        };
        # nix run ".#deploy-azure"
        deploy-azure = {
          type = "app";
          program = toString (pkgs.writers.writeBash "deploy-azure" ''
            set -euo pipefail
            ./scripts/clean-ssh.sh gcp
            ${pkgs.colmena}/bin/colmena apply --on @azure
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
            # scripts/k8s/configure.sh
          '');
        };
      };

      # deploy
      colmena = let
        # read attributes from ouput.json gerated by `nix run .#apply`
        inherit (builtins) fromJSON readFile foldl' attrNames;
        inherit (pkgs.lib.cfg) attrsMap;
        keys = import ./keys; # datacenter: {...}
        genOutput = env:
          let output = fromJSON (readFile ./env/${env}/output.json);
          in (attrsMap output (name:
            let host = output.${name}.value;
            in {
              # generate hosts by name prefix
              ${name} = {
                imports = [ ./generators/minimal-${env}.nix ];
                deployment = {
                  tags = [ env ];
                  targetHost = host.ip.pub;
                  keys = import ./keys;
                };
              };
            })).content;
      in {
        meta = { nixpkgs = pkgs; };
        defaults = import ./deploys/consul;
      } // (genOutput "libvirt") // (genOutput "gcp") // (genOutput "azure");
    };
}
