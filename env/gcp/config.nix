{ config, lib, pkgs, ... }: {
  provision.gcp = {
    enable = true;
    project = "bornlogic-consul";
    networks = {
      prod = { description = "production network"; };
      stag = { description = "staging network"; };
      test = {
        description = "testing network";
        subnetworks = {
          n1 = {
            cidr_range = "10.3.0.0/16";
            description = "n1 network";
            secondary_ranges = [{
              range_name = "test-second-range";
              cidr_range = "10.4.0.0/16";
            }];
          };
        };
      };
    };
    #   volumes = {
    #     nixos = {
    #       source = let
    #         inherit (builtins) readDir attrNames head;
    #         base_dir = ./images/gce;
    #         # get first file of builded generated folder
    #         filename = (head (attrNames (readDir base_dir)));
    #       in base_dir + ./${filename};
    #     };
    #     c1v1 = { source = "nixos"; };
    #     c1v2 = { source = "nixos"; };
    #     c1v3 = { source = "nixos"; };
    #   };
    #   replicas = {
    #     c1r1 = {
    #       interfaces = { n1.addresses = [ "10.0.62.11" ]; };
    #       disks = [ "c1v1" ];
    #     };
    #     c1r2 = {
    #       interfaces = { n1.addresses = [ "10.0.62.12" ]; };
    #       disks = [ "c1v2" ];
    #     };
    #     c1r3 = {
    #       interfaces = { n1.addresses = [ "10.0.62.13" ]; };
    #       disks = [ "c1v3" ];
    #     };
    #   };
  };
}
