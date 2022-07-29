{ config, lib, pkgs, ... }: {
  imports = [ ./provision/libvirt ];
  provision.libvirt = {
    networks = {
      n1 = {
        mode = "nat";
        domain = "n1.local";
        addresses = [ "10.0.62.0/24" ];
        dhcp.enable = true;
        dns.enable = true;
      };
      n2 = {
        mode = "nat";
        domain = "n2.local";
        addresses = [ "10.0.10.0/24" ];
        dhcp.enable = true;
        dns.enable = true;
      };
    };
    volumes = {
      nixos = { source = ./result/nixos.qcow2; };
      v1 = { source = "nixos"; };
      v2 = { source = "nixos"; };
      v3 = { source = "nixos"; };
    };
    replicas = {
      r1 = {
        interfaces = {
          n1.addresses = [ "10.0.62.11" ];
          n2.addresses = [ "10.0.10.11" ];
        };
        disks = [ "v1" ];
      };
      r2 = {
        interfaces = { n1.addresses = [ "10.0.62.12" ]; };
        disks = [ "v2" ];
      };
      r3 = {
        interfaces = { n1.addresses = [ "10.0.62.13" ]; };
        disks = [ "v3" ];
      };
    };
  };

}
