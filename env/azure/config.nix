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

    interfaces = let
      rules = {
        ssh_allow = {
          direction = "Inbound";
          description = "Allow SSH";
          access = "Allow";
          protocol = "Tcp";
          source_port_range = "0";
          source_address_prefix = "*";
          destination_port_range = "22";
          destination_address_prefix = "*";
        };
        allow_all = {
          direction = "Inbound";
          description = "Allow All (Production Unsafe)";
          access = "Allow";
          protocol = "Tcp";
          source_port_range = "*";
          source_address_prefix = "*";
          destination_port_range = "*";
          destination_address_prefix = "*";
        };
      };
    in {
      c2r1 = {
        inherit rules;
        network = "test";
        subnetwork = "n1";
        tags = { description = "mainly c2r1 interface"; };
      };
      c2r2 = {
        inherit rules;
        network = "test";
        subnetwork = "n1";
        tags = { description = "mainly c2r2 interface"; };
      };
      c2r3 = {
        inherit rules;
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
