{ config, lib, pkgs, ... }: {
  provision.gcp = {
    enable = true;
    project = "bornlogic-consul";

    images = {
      nixos = {
        location = "US";
        source = toString
          ../../images/gce/nixos-image-22.05.20220728.9370544-x86_64-linux.raw.tar.gz;
      };
    };

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

    firewall = {
      test-allow-all-to-consul = {
        description = "allow all consul ips to tagged consul machines";
        source_tags = [ "consul" "test" ];
        target_tags = [ "consul" "test" ];
        network = "test";
        allow = [{
          protocol = "tcp";
          ports = [ "0-65535" ];
        }];
      };
    };

    replicas = {
      c1r1 = {
        tags = [ "consul" "server" "nixos" "test" ];
        network = "test";
        subnetwork = "n1";
        machine_type = "e2-medium";
        zone = "us-east1-b";
      };
      c1r2 = {
        tags = [ "consul" "server" "nixos" "test" ];
        network = "test";
        subnetwork = "n1";
        machine_type = "e2-medium";
        zone = "us-east1-c";
      };
      c1r3 = {
        tags = [ "consul" "server" "nixos" "test" ];
        network = "test";
        subnetwork = "n1";
        machine_type = "e2-medium";
        zone = "us-east1-d";
      };

    };

  };
}
