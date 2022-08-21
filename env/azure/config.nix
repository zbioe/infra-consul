{ config, lib, pkgs, ... }: {
  provision.azure = {
    enable = true;
    group = "bornlogic-consul";
    location = "East US 2";
    ssh_keys = import ../../generators/ssh-keys.nix;
    networks = {
      prod = { tags = { env = "production"; }; };
      stag = { tags = { env = "staging"; }; };
      test = {
        tags = { env = "testing"; };
        cidr_ranges = [ "10.0.0.0/16" ];
        subnetworks = { n1 = { cidr_ranges = [ "10.0.1.0/24" ]; }; };
      };
    };

    images = {
      nixos = {
        location = "East US 2";
        source = toString ../../images/azure/disk.vhd;
      };
    };

    interfaces = {
      c2r1 = {
        network = "test";
        subnetwork = "n1";
        tags = { description = "mainly c2r1 interface"; };
      };
      c2r2 = {
        network = "test";
        subnetwork = "n1";
        tags = { description = "mainly c2r2 interface"; };
      };
      c2r3 = {
        network = "test";
        subnetwork = "n1";
        tags = { description = "mainly c2r3 interface"; };
      };
    };

    replicas = {
      c2r1 = {
        tags = {
          image = "nixos";
          service = "consul";
          environment = "test";
        };
        disk_size = 15;
        interfaces = [ "c2r1" ];
      };

      c2r2 = {
        tags = {
          image = "nixos";
          service = "consul";
          environment = "test";
        };
        disk_size = 15;
        interfaces = [ "c2r2" ];
      };

      c2r3 = {
        tags = {
          image = "nixos";
          service = "consul";
          environment = "test";
        };
        disk_size = 15;
        interfaces = [ "c2r3" ];
      };
    };
  };
}
