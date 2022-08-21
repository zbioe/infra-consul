{ config, lib, pkgs, ... }: {
  provision.azure = {
    enable = true;
    group = "bornlogic-consul";

    images = {
      nixos = {
        location = "US";
        source = toString ../../images/azure/disk.vhd;
      };
    };

    # networks = {
    #   prod = { description = "production network"; };
    #   stag = { description = "staging network"; };

    #   test = {
    #     description = "testing network";
    #     subnetworks = {
    #       n1 = {
    #         cidr_range = "10.3.0.0/16";
    #         description = "n1 network";
    #         secondary_ranges = [{
    #           range_name = "test-second-range";
    #           cidr_range = "10.4.0.0/16";
    #         }];
    #       };
    #     };
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
