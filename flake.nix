{
  description = "Consul Deploy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/5516b991bcc4";
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
      overlays.default = import ./overlays;
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
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${terraformConfiguration} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform apply
          '');
        };
        # nix run ".#destroy"
        destroy = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy" ''
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${terraformConfiguration} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform destroy
          '');
        };
        # nix run ".#deploy"
        deploy = {
          type = "app";
          program = toString (pkgs.writers.writeBash "deploy"
            "${pkgs.colmena}/bin/colmena apply");
        };
        # nix run
        default = self.apps.${system}.apply;
      };

      # deploy
      colmena = {
        meta = { nixpkgs = pkgs; };
        defaults = import deploys/consul;
        r1 = { deployment = { targetHost = "10.0.62.11"; }; };
        r2 = { deployment = { targetHost = "10.0.62.12"; }; };
        r3 = { deployment = { targetHost = "10.0.62.13"; }; };
      };
    };
}
