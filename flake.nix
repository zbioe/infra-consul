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
        overlays = [ self.overlay ];
      };
      system = "x86_64-linux";
      terraform =
        pkgs.terraform.withPlugins (p: [ p.null p.external p.libvirt ]);
      terraformConfiguration = terranix.lib.terranixConfiguration {
        inherit system pkgs;
        modules = [ ./provision.nix ];
      };
    in {
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
      overlay = import ./overlays;

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
        # nix run ".#test"
        tests = {
          type = "app";
          program = "TODO";
        };
        # nix run
        default = self.apps.${system}.apply;
      };
    };
}
