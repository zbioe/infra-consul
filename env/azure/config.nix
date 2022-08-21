{ config, lib, pkgs, ... }: {
  provision.azure = {
    enable = true;
    group = "bornlogic-consul";
    location = "East US 2";
    networks = {
      prod = { tags = { env = "production"; }; };
      stag = { tags = { env = "staging"; }; };
      test = {
        tags = { env = "testing"; };
        cidr_ranges = [ "10.0.0.0/16" ];
        subnetworks = { n1 = { cidr_ranges = [ "10.0.1.0/24" ]; }; };
      };
    };

    # images = {
    #   nixos = {
    #     location = "US EAST 2";
    #     source = toString ../../images/azure/disk.vhd;
    #   };
    # };

    # replicas = {
    #   c2r1 = {
    #     tags = [ "consul" "server" "nixos" "test" ];
    #     network = "test";
    #     subnetwork = "n1";
    #     machine_type = "e2-medium";
    #     zone = "us-east1-b";
    #   };
    #   c2r2 = {
    #     tags = [ "consul" "server" "nixos" "test" ];
    #     network = "test";
    #     subnetwork = "n1";
    #     machine_type = "e2-medium";
    #     zone = "us-east1-c";
    #   };
    #   c2r3 = {
    #     tags = [ "consul" "server" "nixos" "test" ];
    #     network = "test";
    #     subnetwork = "n1";
    #     machine_type = "e2-medium";
    #     zone = "us-east1-d";
    #   };
    # };
  };
}
